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
        let mut entries = self.upload_root.read_dir(path).await?;
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
        for path in paths {
            self.upload_root.delete_file(path).await?;
        }
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
