//! This crate contains all shared fullstack server functions.
use std::path::PathBuf;
use std::time::SystemTime;

use chrono::DateTime;
use chrono::Utc;

mod errors;
pub use errors::Error;

mod relative_fs;
pub use relative_fs::RelativeFs;

mod portable_directory;
pub use portable_directory::Directory;
pub use portable_directory::DirectoryEntry;
pub use portable_directory::LookupResult;

mod portable_file;
pub use portable_file::FileStat;

mod portable_path;
pub use portable_path::PortablePath;

/// Formats a file size in bytes into a human-readable string (e.g., KB, MB).
///
/// # Arguments
/// * `size` - The file size in bytes.
///
/// # Returns
/// * `String` - The formatted file size.
pub fn format_file_size(size: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = size as f64;
    let mut unit_index = 0;

    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", size as u64, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

/// Formats a `SystemTime` into a RFC 3339 - Z format.
/// For example "2018-01-26T18:30:09.453Z"
///
/// # Arguments
/// * `time` - The system time to format.
///
/// # Returns
/// * `String` - The formatted date and time string.
pub fn format_system_time(time: SystemTime) -> String {
    let datetime: DateTime<Utc> = time.into();
    datetime.to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
}

/// Represents an uploaded file with its path and contents.
pub struct UploadedFile {
    /// The path to the uploaded file.
    pub path: PathBuf,
    /// The contents of the uploaded file as bytes.
    pub contents: Vec<u8>,
}

/// Loads uploaded files. Currently returns an empty vector.
///
/// # Returns
/// * `Vec<UploadedFile>` - A vector of uploaded files.
pub fn load_files() -> Vec<UploadedFile> {
    Vec::new()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_path() {
        let path = PortablePath {
            components: vec![
                "dir1".to_string(),
                "dir2".to_string(),
                "file.txt".to_string(),
            ],
        };
        let s = "{\"components\":[\"dir1\",\"dir2\",\"file.txt\"]}";
        assert_eq!(s, &serde_json::to_string(&path).unwrap());
        assert_eq!(path, serde_json::from_str(s).unwrap());
    }
}
