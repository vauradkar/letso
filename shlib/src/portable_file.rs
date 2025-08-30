use std::fs::Metadata;
use std::time::SystemTime;

use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;

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
}

impl From<&Metadata> for FileStat {
    fn from(metadata: &Metadata) -> Self {
        let modified = metadata.modified().unwrap_or(SystemTime::UNIX_EPOCH);
        FileStat {
            size: metadata.len(),
            mtime: format_system_time(modified),
            is_directory: metadata.is_dir(),
        }
    }
}
