use std::fs::read_dir;
use std::path::Path;
use std::path::PathBuf;

use async_walkdir::Filtering;
use async_walkdir::WalkDir;
use futures_lite::stream::StreamExt;
use log::debug;
use log::error;
use log::info;
use log::trace;
use tokio::sync::mpsc;
use tokio::sync::mpsc::Sender;

use crate::DeltaExchange;
use crate::Directory;
use crate::DirectoryEntry;
use crate::Error;
use crate::FileStat;
use crate::PortablePath;
use crate::SyncItem;
use crate::format_system_time;
use crate::parse_system_time;

async fn recurse_path_sender_err(
    base_dir: PathBuf,
    full_path: PathBuf,
    tx: Sender<Vec<SyncItem>>,
    chunk_size: usize,
) -> Result<(), Error> {
    let mut entries = WalkDir::new(&full_path).filter(|entry| async move {
        if let Ok(metadata) = entry.metadata().await
            && metadata.is_dir()
        {
            return Filtering::Continue;
        }
        Filtering::Continue
    });
    let mut chunks = Vec::with_capacity(chunk_size);
    loop {
        match entries.next().await {
            Some(Ok(entry)) => {
                debug!("entry path: {}", entry.path().display());
                let stats = FileStat::from_dir_entry(&entry).await?;
                let relative_path = entry
                    .path()
                    .strip_prefix(&base_dir)
                    .map_err(|e| Error::ReadError {
                        what: "strip_prefix".into(),
                        how: e.to_string(),
                    })?
                    .to_owned();
                let portable_path = PortablePath::try_from(&relative_path)?;
                chunks.push(SyncItem {
                    path: portable_path,
                    stats: Some(stats),
                });
                if chunks.len() == chunk_size {
                    tx.send(std::mem::take(&mut chunks))
                        .await
                        .map_err(|e| Error::SyncFailed {
                            what: "failed to tx".to_owned(),
                            how: e.to_string(),
                        })?;
                    if chunks.capacity() < chunk_size {
                        chunks.reserve(chunk_size - chunks.capacity());
                    }
                }
            }
            Some(Err(e)) => {
                return Err(Error::ReadError {
                    what: "walkdir".into(),
                    how: e.to_string(),
                });
            }
            None => {
                if !chunks.is_empty() {
                    tx.send(std::mem::take(&mut chunks))
                        .await
                        .map_err(|e| Error::SyncFailed {
                            what: "failed to tx".to_owned(),
                            how: e.to_string(),
                        })?;
                }
                break;
            }
        }
    }
    Ok(())
}

/// Represents a filesystem rooted at a relative base directory.
pub struct RelativeFs {
    /// The relative path from the base directory.
    pub base_dir: PathBuf,
}

impl From<PathBuf> for RelativeFs {
    fn from(path: PathBuf) -> Self {
        RelativeFs { base_dir: path }
    }
}

impl RelativeFs {
    /// Converts a relative PortablePath to an absolute PathBuf based on the
    /// base_dir.
    ///
    /// # Arguments
    /// * `relative` - The relative PortablePath to convert.
    ///
    /// # Returns
    /// * `PathBuf` - The absolute path corresponding to the relative path.
    pub fn as_abs_path(&self, relative: &PortablePath) -> PathBuf {
        let mut full_path = self.base_dir.clone();
        let rel: PathBuf = relative.into();
        full_path.push(rel);
        // for component in &relative.components {
        //     if component !=
        // std::path::Component::RootDir.as_os_str().to_str().unwrap() {
        //         full_path.push(component);
        //     }
        // }
        full_path
    }

    /// Browses the contents of the given directory path and returns its
    /// entries.
    ///
    /// # Arguments
    /// * `current_path` - The path to the directory to browse.
    ///
    /// # Returns
    /// * `Result<DirectoryEntries, Error>` - The directory entries or an error
    ///   message.
    pub async fn browse_path(&self, path: &PortablePath) -> Result<Directory, Error> {
        let full_path = self.as_abs_path(path);

        let mut items =
            Self::list_directory_contents(&full_path).map_err(|e| Error::ReadError {
                what: "list directory".into(),
                how: e.to_string(),
            })?;

        // Sort: directories first, then files, both alphabetically
        items.sort_by(|a, b| match (a.stats.is_directory, b.stats.is_directory) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        });

        Ok(Directory {
            current_path: path.clone(),
            items,
        })
    }

    /// Recursively walks directory `path`` and returns files and their metadata
    /// under the directory tree.
    ///
    /// # Arguments
    /// * `path` - The path to the directory to browse.
    ///
    /// # Returns
    /// * `Result<DirectoryEntries, Error>` - The directory entries or an error
    ///   message.
    pub async fn recurse_path(&self, path: &PortablePath) -> Result<Vec<SyncItem>, Error> {
        let (tx, mut rx) = mpsc::channel(100);
        let base_dir = self.base_dir.clone();
        let full_path = self.as_abs_path(path);
        let x =
            tokio::spawn(async move { recurse_path_sender_err(base_dir, full_path, tx, 20).await });
        let mut items = Vec::new();
        while let Some(mut item) = rx.recv().await {
            items.append(&mut item);
        }
        x.await.unwrap()?;
        Ok(items)
    }

    /// Exchanges file deltas by sending SyncItem objects for the given
    /// destination path over the provided channel.
    ///
    /// # Arguments
    /// * `tx` - The channel sender to transmit SyncItem objects.
    /// * `delta` - The DeltaRequest containing the destination path to recurse.
    pub async fn exchange_deltas(
        &self,
        tx: Sender<Vec<SyncItem>>,
        delta: DeltaExchange,
        chunk_size: usize,
    ) {
        let base_dir = self.base_dir.clone();
        let full_path = self.as_abs_path(&delta.dest);
        debug!(
            "exchange_deltas base_dir: {} full_path:{} dest:{}",
            base_dir.display(),
            full_path.display(),
            delta.dest
        );
        _ = recurse_path_sender_err(base_dir, full_path, tx, chunk_size).await;
    }

    /// Lists the contents of a directory and returns their metadata.
    ///
    /// # Arguments
    /// * `full_path` - The path to the directory to list.
    ///
    /// # Returns
    /// * `Result<Vec<FileStat>, String>` - A vector of file statistics or an
    ///   error message.
    fn list_directory_contents(full_path: &Path) -> Result<Vec<DirectoryEntry>, Error> {
        if !full_path.exists() {
            return Err(Error::InvalidArgument("Path does not exist".to_string()));
        }

        if !full_path.is_dir() {
            return Err(Error::InvalidArgument(
                "Path is not a directory".to_string(),
            ));
        }

        let mut items = Vec::new();

        info!("full path: {}", full_path.display());
        // Read directory contents
        let entries = read_dir(full_path).map_err(|e| Error::ReadError {
            what: "directory".into(),
            how: e.to_string(),
        })?;

        for entry in entries {
            let entry = entry.map_err(|e| Error::ReadError {
                what: "entry".into(),
                how: e.to_string(),
            })?;

            let metadata = entry.metadata().map_err(|e| Error::ReadError {
                what: "metadata".into(),
                how: e.to_string(),
            })?;

            let relative_path = entry.file_name();

            let modified = metadata.modified().map_err(|e| Error::ReadError {
                what: "modified time".into(),
                how: e.to_string(),
            })?;

            trace!(
                "relative_path: {}, is_directory: {}, size: {}, modified: {}",
                relative_path.display(),
                metadata.is_dir(),
                metadata.len(),
                format_system_time(modified)
            );
            items.push(DirectoryEntry {
                name: relative_path.to_str().unwrap().to_owned(),
                stats: (&metadata).into(),
            });
        }
        trace!("line: {} items: {:?}", line!(), items);
        Ok(items)
    }

    async fn create_all(&self, path: &PortablePath) -> Result<(), String> {
        let full_path = self.as_abs_path(path);
        tokio::fs::create_dir_all(&full_path).await.map_err(|e| {
            error!("Failed to create directory {} {}", e, full_path.display());
            format!("Failed to create directories: {e}")
        })?;
        Ok(())
    }

    /// Writes data to a file at the specified path, optionally overwriting if
    /// the file exists.
    ///
    /// # Arguments
    /// * `path` - The path to the file to write.
    /// * `data` - The data to write to the file.
    /// * `overwrite` - Whether to overwrite the file if it already exists.
    ///
    /// # Returns
    /// * `Result<(), String>` - Ok if successful, or an error message.
    pub async fn write(
        &self,
        path: &PortablePath,
        data: &[u8],
        overwrite: bool,
        stats: &FileStat,
    ) -> Result<(), Error> {
        let full_path = self.as_abs_path(path);
        if full_path.exists() && !overwrite {
            return Err(Error::FileExists(full_path.to_string_lossy().to_string()));
        }
        self.create_all(&path.parent().unwrap())
            .await
            .map_err(|e| Error::CreateFailed {
                what: path.parent().unwrap().to_string(),
                how: e,
            })?;
        tokio::fs::write(&full_path, data)
            .await
            .map_err(|e| Error::WriteFailed {
                what: full_path.to_str().unwrap().into(),
                how: e.to_string(),
            })?;
        let mtime = parse_system_time(&stats.mtime)?;
        let full_path_clone = full_path.clone();
        // Update mtime of the file if stats provided
        tokio::task::spawn_blocking(move || -> Result<(), std::io::Error> {
            let file = std::fs::File::options()
                .append(true)
                .open(&full_path_clone)?;
            file.set_modified(mtime)
        })
        .await
        .map_err(|e| Error::WriteFailed {
            what: full_path.to_str().unwrap().into(),
            how: e.to_string(),
        })?
        .map_err(|e| Error::WriteFailed {
            what: full_path.to_str().unwrap().into(),
            how: e.to_string(),
        })
    }

    /// Deletes the file at the specified path.
    pub async fn delete_file(&self, path: &PortablePath) -> Result<(), Error> {
        let full_path = self.as_abs_path(path);
        if !full_path.exists() {
            return Err(Error::InvalidArgument("File does not exist".to_string()));
        }
        if full_path.is_dir() {
            return Err(Error::InvalidArgument("Path is a directory".to_string()));
        }
        tokio::fs::remove_file(&full_path)
            .await
            .map_err(|e| Error::DeleteFailed {
                what: full_path.to_str().unwrap().into(),
                how: e.to_string(),
            })
    }

    /// Reads the contents of the file at the specified path.
    pub async fn read_file(&self, path: &PortablePath) -> Result<Vec<u8>, Error> {
        let full_path = self.as_abs_path(path);
        if !full_path.exists() {
            return Err(Error::InvalidArgument("File does not exist".to_string()));
        }
        if full_path.is_dir() {
            return Err(Error::InvalidArgument("Path is a directory".to_string()));
        }
        tokio::fs::read(&full_path)
            .await
            .map_err(|e| Error::ReadError {
                what: full_path.to_str().unwrap().into(),
                how: e.to_string(),
            })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::TestRoot;
    #[tokio::test]
    async fn test_recurse_path() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs {
            base_dir: root.root.path().to_path_buf(),
        };

        let r = fs
            .recurse_path(&PortablePath::try_from(&Path::new("").to_owned()).unwrap())
            .await
            .unwrap();

        println!("r: {r:#?}");
        root.are_synced(&r).unwrap();
    }
}
