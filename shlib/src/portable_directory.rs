use poem_openapi::Object;
use serde::Deserialize;
use serde::Serialize;

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
pub struct LookupResult {
    /// The full path of the file.
    pub path: PortablePath,
    /// Metadata if the file exists.
    pub stats: Option<FileStat>,
}
