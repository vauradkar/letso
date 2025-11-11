use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;

use crate::Error;
use crate::FileStat;
use crate::PortablePath;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Object)]
/// Represents a file or directory entry, including its name and associated
/// metadata.
pub struct DirectoryEntry {
    /// Name of the file or directory.
    pub name: String,
    /// Metadata of the file or directory.
    pub stats: FileStat,
}

impl TryFrom<&SyncItem> for DirectoryEntry {
    type Error = Error;
    fn try_from(item: &SyncItem) -> Result<Self, crate::Error> {
        let name = item
            .path
            .basename()
            .ok_or(Error::InvalidPath {
                what: item.path.to_string(),
            })?
            .to_string();
        let stats = item.stats.clone().ok_or(Error::ReadError {
            what: "failed to lookup stats".to_owned(),
            how: "none found".to_owned(),
        })?;
        Ok(DirectoryEntry { name, stats })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Object)]
/// Represents the contents of a directory, including the current path and its
/// items.
pub struct Directory {
    /// The current directory path.
    pub current_path: PortablePath,
    /// The list of files and directories in the current path.
    pub items: Vec<DirectoryEntry>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Object)]
/// Represents the contents of a directory, including the current path and its
/// items.
pub struct SyncItem {
    /// The full path of the file.
    pub path: PortablePath,
    /// Metadata if the file exists.
    pub stats: Option<FileStat>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Object)]
/// a struct to represent the exchange of delta.
pub struct DeltaExchange {
    /// Path where the directory should be synced
    pub dest: PortablePath,
    /// List of SyncItems representing the deltas
    pub deltas: Vec<SyncItem>,
}
