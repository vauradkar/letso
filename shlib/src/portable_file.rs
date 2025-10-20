use std::fs::Metadata;
use std::path::Path;
use std::time::SystemTime;

use async_walkdir::DirEntry;
use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;
use sha2::Digest;
use sha2::Sha256;
use tokio::fs;
use tokio::io::AsyncReadExt;

use crate::Error;
use crate::format_system_time;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Object)]
/// Represents the metadata of a file or directory, including its path, size,
/// modification time, and type.
pub struct FileStat {
    /// The size of the file in bytes. For directories, this may be zero or
    /// implementation-defined.
    pub size: u64,
    /// The last modification time of the file or directory in RFC 3339 - Z
    /// format. For example "2018-01-26T18:30:09.453Z"
    pub mtime: String,
    /// Whether this entry is a directory.
    pub is_directory: bool,
    /// Optional digest of the file contents.
    pub sha256: Option<String>,
}

impl FileStat {
    /// Creates a `FileStat` from a directory entry, including digest for files.
    pub async fn from_dir_entry(entry: &DirEntry) -> Result<Self, Error> {
        let path = entry.path();
        Self::from_path(&path).await
    }

    /// Creates a `FileStat` from a directory entry, including digest for files.
    pub async fn from_path<P: AsRef<Path>>(path: P) -> Result<Self, Error> {
        let path = path.as_ref();
        let metadata = fs::metadata(&path).await.map_err(|e| Error::ReadError {
            what: "metadata".into(),
            how: e.to_string(),
        })?;
        let mut ret = FileStat::from(&metadata);
        if ret.is_directory {
            return Ok(ret);
        }

        let mut file = fs::File::open(path).await.map_err(|e| Error::ReadError {
            what: path.to_string_lossy().to_string(),
            how: e.to_string(),
        })?;
        let mut hasher = Sha256::new();
        let mut buffer = vec![0; 4096]; // Read in chunks

        let mut n = 0_u64;
        loop {
            let bytes_read = file.read(&mut buffer).await.map_err(|e| Error::ReadError {
                what: path.to_string_lossy().to_string(),
                how: e.to_string(),
            })?;

            if bytes_read == 0 {
                break; // End of file
            }
            n += bytes_read as u64;
            hasher.update(&buffer[..bytes_read]);
        }

        let hash = hasher.finalize();
        if n == ret.size {
            let digest = format!("{hash:x}");
            ret.sha256 = Some(digest);
        }

        Ok(ret)
    }
}

impl From<&Metadata> for FileStat {
    fn from(metadata: &Metadata) -> Self {
        let modified = metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        FileStat {
            size: metadata.len(),
            mtime: format_system_time(modified),
            is_directory: metadata.is_dir(),
            sha256: None,
        }
    }
}
