use std::num::NonZeroUsize;
use std::path::Path;
use std::path::PathBuf;
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::MutexGuard;

use log::debug;
use log::error;
use tokio::sync::mpsc::Sender;

use crate::Cache;
use crate::DeltaExchange;
use crate::DirWalker;
use crate::Directory;
use crate::DirectoryEntry;
use crate::Error;
use crate::FileStat;
use crate::PortablePath;
use crate::SyncItem;
use crate::parse_system_time;

pub(crate) async fn lookup_or_load(
    cache: Arc<Mutex<Cache>>,
    path: &Path,
    portable_path: &PortablePath,
) -> Result<FileStat, Error> {
    if let Some(stats) = cache.lock().unwrap().get(portable_path) {
        Ok(stats.clone())
    } else {
        let stats = FileStat::from_path(path).await?;
        cache
            .lock()
            .unwrap()
            .put(portable_path.clone(), stats.clone());
        Ok(stats)
    }
}

/// Represents a filesystem rooted at a relative base directory.
pub struct RelativeFs {
    /// The relative path from the base directory.
    pub base_dir: PathBuf,

    cache: Arc<Mutex<Cache>>,
}

impl From<PathBuf> for RelativeFs {
    fn from(path: PathBuf) -> Self {
        RelativeFs {
            base_dir: path,
            cache: Arc::new(Mutex::new(Cache::new(NonZeroUsize::new(1000).unwrap()))),
        }
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
        let mut items = Vec::new();
        for item in DirWalker::walk_dir(
            full_path,
            self.base_dir.clone(),
            self.cache.clone(),
            20,
            Some(0),
        )
        .await?
        {
            items.push(DirectoryEntry::try_from(&item)?);
        }

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
        DirWalker::walk_dir(
            self.as_abs_path(path),
            self.base_dir.clone(),
            self.cache.clone(),
            20,
            None,
        )
        .await
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
        let full_path = self.as_abs_path(&delta.dest);
        let strip_prefix = if let Some(parent) = delta.dest.parent() {
            self.as_abs_path(&parent)
        } else {
            full_path.clone()
        };
        debug!(
            "exchange_deltas base_dir: {} full_path:{} dest:{}",
            self.base_dir.display(),
            full_path.display(),
            delta.dest
        );
        let dir_walker = DirWalker::create(strip_prefix, self.cache.clone(), chunk_size, None, tx);
        if let Err(e) = dir_walker.walk_dir_stream(&full_path).await {
            error!("exchange_deltas error: {}", e);
        }
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

        if let Some(parent) = path.parent() {
            self.create_all(&parent)
                .await
                .map_err(|e| Error::CreateFailed {
                    what: path.parent().unwrap().to_string(),
                    how: e,
                })?;
        }
        tokio::fs::write(&full_path, data)
            .await
            .map_err(|e| Error::WriteFailed {
                what: full_path.to_str().unwrap().into(),
                how: e.to_string(),
            })?;
        let mtime = parse_system_time(&stats.mtime)?;
        let full_path_clone = full_path.clone();
        // Update mtime of the file if stats provided
        let ret = tokio::task::spawn_blocking(move || -> Result<(), std::io::Error> {
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
        });
        if ret.is_ok() {
            self.get_cache().put(path.clone(), stats.clone());
        }
        ret
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
        let ret = tokio::fs::remove_file(&full_path)
            .await
            .map_err(|e| Error::DeleteFailed {
                what: full_path.to_str().unwrap().into(),
                how: e.to_string(),
            });
        if ret.is_ok() {
            self.get_cache().pop(path);
        }
        ret
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

    fn get_cache(&'_ self) -> MutexGuard<'_, Cache> {
        self.cache.lock().unwrap()
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;
    use std::time::SystemTime;

    use tokio::sync::mpsc;

    use super::*;
    use crate::Sha256Builder;
    use crate::Sha256String;
    use crate::TestRoot;
    use crate::cache::CacheStats;
    use crate::format_system_time;
    use crate::test_utils::TEMP_FILES;
    #[tokio::test]
    async fn test_recurse_path() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        let r = fs
            .recurse_path(&PortablePath::try_from(&Path::new("").to_owned()).unwrap())
            .await
            .unwrap();

        println!("r: {r:#?}");
        root.are_synced(&r).unwrap();
    }

    #[tokio::test]
    async fn test_browse_path() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        // Browse the directory
        let portable_path = PortablePath::try_from(&Path::new("").to_owned()).unwrap();
        let directory = fs.browse_path(&portable_path).await.unwrap();

        // Assert the directory contains the file
        let mut entries: HashSet<String> = ["file1.txt", "file2.txt", "dir1", "dir3"]
            .iter()
            .map(|s| s.to_string())
            .collect();
        assert_eq!(directory.items.len(), 4);
        for entry in &directory.items {
            println!("entry name: {}", entry.name);
            assert!(entries.remove(&entry.name));
        }
        assert!(entries.is_empty());
        root.match_entries(&directory);
    }

    async fn get_deltaa(path: &str) -> HashSet<String> {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        // Set up the channel
        let (tx, mut rx) = mpsc::channel(10);
        let delta = DeltaExchange {
            dest: PortablePath::try_from(&Path::new(path).to_owned()).unwrap(),
            deltas: vec![],
        };

        // Call exchange_deltas
        fs.exchange_deltas(tx, delta, 10).await;

        // Assert the channel received the correct SyncItem
        let mut received_items = Vec::new();
        while let Some(items) = rx.recv().await {
            received_items.extend(items);
        }
        println!("received_items: {:#?}", received_items);
        let mut received_files = HashSet::new();
        received_items.iter().for_each(|i| {
            received_files.insert(i.path.to_string());
        });
        received_files
    }

    #[tokio::test]
    async fn test_exchange_deltas_rootdir() {
        let expected_files = get_deltaa("").await;
        let mut files_found = 0;
        for file in TEMP_FILES {
            files_found += 1;
            assert!(
                expected_files.contains(file.0),
                "{:?} Missing file: {} ",
                expected_files,
                file.0
            );
        }
        assert_eq!(
            files_found,
            expected_files.len(),
            "Expected files: {:?}",
            expected_files
        );
    }

    #[tokio::test]
    async fn test_exchange_deltas_subdir() {
        let expected_files = get_deltaa("dir1").await;
        let mut files_found = 0;
        for file in TEMP_FILES {
            if file.0.contains("dir1") && file.0 != "dir1" {
                files_found += 1;
                assert!(
                    expected_files.contains(file.0),
                    "{:?} Missing file: {} ",
                    expected_files,
                    file.0
                );
            }
        }
        assert_eq!(
            files_found,
            expected_files.len(),
            "Expected files: {:?}",
            expected_files
        );
    }

    async fn write_file(fs: &RelativeFs, portable_path: &PortablePath, data: &[u8]) -> FileStat {
        let modified = SystemTime::now();
        let stats = FileStat {
            size: data.len() as u64,
            mtime: format_system_time(modified),
            is_directory: false,
            sha256: Some(
                data.sha256_build()
                    .await
                    .unwrap()
                    .sha256_string()
                    .await
                    .unwrap(),
            ),
        };

        fs.write(portable_path, data, true, &stats).await.unwrap();
        stats
    }

    #[tokio::test]
    async fn test_write() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        let fpath: &[&str] = &["test_file.txt"];
        let portable_path = PortablePath::try_from(fpath).unwrap();
        let data: &[u8] = b"Hello, world!";
        let stats = write_file(&fs, &portable_path, data).await;

        // Assert the file exists and contains the correct data
        let full_path = fs.as_abs_path(&portable_path);
        assert!(full_path.exists());
        let contents = tokio::fs::read(&full_path).await.unwrap();
        assert_eq!(contents, data);
        let metadata = tokio::fs::metadata(&full_path).await.unwrap();
        assert_eq!(metadata.len(), data.len() as u64);
        assert_eq!(
            parse_system_time(&stats.mtime).unwrap(),
            metadata.modified().unwrap()
        );
        assert_eq!(
            stats.sha256.as_ref().unwrap(),
            &data
                .sha256_build()
                .await
                .unwrap()
                .sha256_string()
                .await
                .unwrap()
        );
    }

    #[tokio::test]
    async fn test_delete_file() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        // Create a test file
        let portable_path = PortablePath::try_from(&Path::new("test_file.txt").to_owned()).unwrap();
        let full_path = fs.as_abs_path(&portable_path);
        tokio::fs::write(&full_path, b"Hello, world!")
            .await
            .unwrap();

        // Delete the file
        fs.delete_file(&portable_path).await.unwrap();

        // Assert the file no longer exists
        assert!(!full_path.exists());
    }

    fn check_len(cache: &Cache, expected_len: u64) {
        let len = cache.len();
        if len != expected_len {
            cache.dump_keys();
        }
        assert_eq!(len, expected_len);
    }

    #[tokio::test]
    async fn test_cache() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let fs = RelativeFs::from(root.root.path().to_path_buf());

        let mut cstats = CacheStats::default();
        check_len(&fs.get_cache(), 0);
        check_len(&fs.get_cache(), 0);
        assert_eq!(fs.get_cache().stats(), &cstats);

        let fpath: &[&str] = &["test_file.txt"];
        let portable_path = PortablePath::try_from(fpath).unwrap();
        let data: &[u8] = b"Hello, world!";
        let stats = write_file(&fs, &portable_path, data).await;
        assert_eq!(fs.get_cache().stats(), &cstats);

        assert_eq!(fs.get_cache().get(&portable_path).unwrap(), &stats);
        check_len(&fs.get_cache(), 1);
        cstats.hits += 1;
        assert_eq!(fs.get_cache().stats(), &cstats);

        fs.delete_file(&portable_path).await.unwrap();
        check_len(&fs.get_cache(), 0);
        assert_eq!(fs.get_cache().stats(), &cstats);
        assert_eq!(fs.get_cache().get(&portable_path), None);
        cstats.misses += 1;
        assert_eq!(fs.get_cache().stats(), &cstats);

        let _ = fs
            .browse_path(&PortablePath::try_from(&PathBuf::from("")).unwrap())
            .await;
        check_len(&fs.get_cache(), 4);
        cstats.misses += 4;
        assert_eq!(fs.get_cache().stats(), &cstats);

        let old_len = fs.get_cache().len();
        let _ = fs
            .recurse_path(&PortablePath::try_from(&PathBuf::from("")).unwrap())
            .await
            .unwrap();
        check_len(&fs.get_cache(), root.files.len() as u64);
        cstats.hits += old_len;
        cstats.misses += root.files.len() as u64 - old_len as u64;
        assert_eq!(fs.get_cache().stats(), &cstats);
    }
}
