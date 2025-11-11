use thiserror::Error;

/// Represents all possible errors in the shlib crate.
#[derive(Error, Debug)]
pub enum Error {
    /// Error indicating a failure to read data.
    #[error("Failed to read {what}: {how}")]
    ReadError {
        /// The item that failed to be read.
        what: String,
        /// The reason for the failure.
        how: String,
    },
    /// Error indicating an invalid argument was provided.
    #[error("Invalid argument: {0}")]
    InvalidArgument(String),

    /// Error indicating a failure to parse data.
    #[error("Failed to parse {what}: {how}")]
    ParseError {
        /// The item that failed to be parse.
        what: String,
        /// The reason for the failure.
        how: String,
    },

    /// Error indicating that a file already exists at the specified path.
    #[error("File already exists: {0}")]
    FileExists(String),

    /// Error indicating a failure to create a file or directory.
    #[error("Failed to create {what}: {how}")]
    CreateFailed {
        /// The item that failed to be created.
        what: String,
        /// The reason for the failure.
        how: String,
    },

    /// Error indicating a failure to write data to a file.
    #[error("Failed to write {what}: {how}")]
    WriteFailed {
        /// The item that failed to be written.
        what: String,
        /// The reason for the failure.
        how: String,
    },

    /// Error indicating a failure to delete a file.
    #[error("Failed to delete {what}: {how}")]
    DeleteFailed {
        /// The item that failed to be deleted.
        what: String,
        /// The reason for the failure.
        how: String,
    },

    /// Error indicating a failure to sync file(s).
    #[error("Sync failed {what}: {how}")]
    SyncFailed {
        /// Specific failure type
        what: String,
        /// The potential  reason for the failure.
        how: String,
    },

    /// Error indicating an invalid path.
    #[error("Invalid path: {what}")]
    InvalidPath {
        /// The invalid path description.
        what: String,
    },
}
