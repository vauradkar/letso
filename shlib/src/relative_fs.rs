use std::fs::read_dir;
use std::path::Path;
use std::path::PathBuf;

use log::debug;
use log::info;

use crate::Directory;
use crate::DirectoryEntry;
use crate::Error;
use crate::FileStat;
use crate::PortablePath;
use crate::format_system_time;

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
        for component in &relative.components {
            if component != std::path::Component::RootDir.as_os_str().to_str().unwrap() {
                full_path.push(component);
            }
        }
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

        debug!("line: {} incoming:{}", line!(), full_path.display());

        let mut items =
            Self::list_directory_contents(&full_path).map_err(|e| Error::ReadError {
                what: "list directory".into(),
                how: e.to_string(),
            })?;

        debug!("line: {}", line!());
        // Sort: directories first, then files, both alphabetically
        items.sort_by(|a, b| match (a.stats.is_directory, b.stats.is_directory) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => a.name.cmp(&b.name),
        });

        debug!("line: {} outgoinf:{}", line!(), full_path.display());

        Ok(Directory {
            current_path: path.clone(),
            items,
        })
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

        info!("line: {} {}", line!(), full_path.display());
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

            info!(
                "relative_path: {}, is_directory: {}, size: {}, modified: {}",
                relative_path.display(),
                metadata.is_dir(),
                metadata.len(),
                format_system_time(modified)
            );
            items.push(DirectoryEntry {
                name: relative_path.to_str().unwrap().to_owned(),
                stats: FileStat {
                    is_directory: metadata.is_dir(),
                    size: metadata.len(),
                    mtime: format_system_time(modified),
                },
            });
        }
        info!("line: {} items: {:?}", line!(), items);
        Ok(items)
    }

    async fn create_all(&self, path: &PortablePath) -> Result<(), String> {
        let full_path = self.as_abs_path(path);
        tokio::fs::create_dir_all(&full_path)
            .await
            .map_err(|e| format!("Failed to create directories: {e}"))?;
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
