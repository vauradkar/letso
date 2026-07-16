use std::path::PathBuf;

use log::debug;
use pfs::Directory;
use pfs::Error;
use pfs::FileInfo;
use pfs::FileStat;
use pfs::Path;
use pfs::PortableFs;
use pfs::RecursiveDirList;
use poem_openapi::Multipart;
use poem_openapi::types::multipart::JsonField;
use poem_openapi::types::multipart::Upload;
use tokio::sync::mpsc::Sender;

use crate::args::Args;

// a struct to represent the multipart form data, including the file.
#[derive(Debug, Multipart)]
pub(crate) struct UploadFileRequest {
    #[oai(rename = "file")] // Rename the field to "file" in the form data
    file: Upload, // Represents the uploaded file
    pub path: JsonField<Path>,  // Path where the file should be uploaded
    overwrite: bool,            // Whether to overwrite existing files
    stats: JsonField<FileStat>, // Optional checksum field
}

pub struct AppState {
    upload_root: PortableFs,
    pub(crate) ui_dir: Option<PathBuf>,
    pub buffer_items: usize,
    pub chunk_count: usize,
}

impl AppState {
    pub async fn browse_path(&self, path: &Path) -> Result<Directory, Error> {
        let mut entries = self.upload_root.read_dir(path, false).await?;
        entries.current_path = path.clone();
        Ok(entries)
    }

    pub async fn save_uploaded_file(&self, form: UploadFileRequest) -> Result<(), Error> {
        // Access the uploaded file data
        let filename = form.file.file_name().unwrap_or("unknown_file");
        let content_type = form
            .file
            .content_type()
            .unwrap_or("application/octet-stream");
        let mut path = form.path.0.clone();
        path.push(filename);

        debug!(
            "Received file: {filename} Content-Type: {content_type} Upload path: {} stats: {:?}",
            path, form.stats
        );
        self.upload_root
            .write(
                &path,
                &form.file.into_vec().await.unwrap(),
                form.overwrite,
                &form.stats.0,
            )
            .await?;

        Ok(())
    }

    pub async fn delete_files(&self, paths: &[Path]) -> Result<(), Error> {
        // Use `join_all` rather than `try_join_all` so that every deletion
        // runs to completion even if another path fails; short-circuiting
        // would leave in-flight `tokio::fs::remove_file` blocking tasks
        // racing with anything that reads the directory right after this
        // function returns.
        futures_util::future::join_all(paths.iter().map(|path| self.upload_root.delete_file(path)))
            .await
            .into_iter()
            .collect::<Result<Vec<()>, Error>>()?;
        Ok(())
    }

    pub async fn read_file(&self, path: &Path) -> Result<Vec<u8>, Error> {
        self.upload_root.read_file(path).await
    }

    pub async fn exchange_deltas(
        &self,
        tx: Sender<Vec<FileInfo>>,
        delta: RecursiveDirList,
        chunk_size: usize,
    ) {
        self.upload_root
            .exchange_deltas(tx, delta, chunk_size)
            .await
    }
}

impl TryFrom<&Args> for AppState {
    type Error = String;

    fn try_from(args: &Args) -> std::result::Result<Self, Self::Error> {
        let upload_root = args
            .upload_root
            .clone()
            .canonicalize()
            .map_err(|e| format!("Failed to canonicalize upload_root: {e}"))?;
        let ui_dir = args
            .ui_dir
            .clone()
            .map(|p| {
                p.canonicalize()
                    .map_err(|e| format!("Failed to canonicalize ui_dir: {e}"))
            })
            .transpose()?;

        // Ensure uploads directory exists
        if !upload_root.exists() {
            std::fs::create_dir_all(&upload_root)
                .map_err(|e| format!("Failed to create upload directory: {e}"))?;
        }
        Ok(AppState {
            upload_root: PortableFs::with_cache(upload_root),
            ui_dir,
            buffer_items: args.buffer_items,
            chunk_count: args.chunk_count,
        })
    }
}

#[cfg(test)]
mod tests {
    use pfs::TestRoot;

    use super::*;

    fn app_state(root: &TestRoot) -> AppState {
        AppState {
            upload_root: PortableFs::with_cache(root.root.path().to_path_buf()),
            ui_dir: None,
            buffer_items: 10,
            chunk_count: 10,
        }
    }

    #[tokio::test]
    async fn delete_files_removes_all_given_files() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let state = app_state(&root);
        let paths = [
            Path::try_from(std::path::Path::new("file1.txt")).unwrap(),
            Path::try_from(std::path::Path::new("file2.txt")).unwrap(),
            Path::try_from(std::path::Path::new("dir1/file3.txt")).unwrap(),
        ];

        state.delete_files(&paths).await.unwrap();

        for path in &paths {
            assert!(!state.upload_root.as_abs_path(path).exists());
        }
    }

    #[tokio::test]
    async fn delete_files_errors_on_missing_file_without_panicking() {
        let root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let state = app_state(&root);
        let paths = [
            Path::try_from(std::path::Path::new("file1.txt")).unwrap(),
            Path::try_from(std::path::Path::new("does_not_exist.txt")).unwrap(),
        ];

        assert!(state.delete_files(&paths).await.is_err());
    }
}
