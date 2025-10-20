use std::path::PathBuf;

use log::debug;
use poem_openapi::Multipart;
use poem_openapi::types::multipart::JsonField;
use poem_openapi::types::multipart::Upload;
use shlib::Directory;
use shlib::Error;
use shlib::FileStat;
use shlib::PortablePath;
use shlib::RelativeFs;
use shlib::SyncItem;
use tokio::sync::mpsc::Sender;

use crate::args::Args;

// a struct to represent the multipart form data, including the file.
#[derive(Debug, Multipart)]
pub(crate) struct UploadFileRequest {
    #[oai(rename = "file")] // Rename the field to "file" in the form data
    file: Upload, // Represents the uploaded file
    pub path: JsonField<PortablePath>, // Path where the file should be uploaded
    overwrite: bool,                   // Whether to overwrite existing files
    stats: JsonField<FileStat>,        // Optional checksum field
}

pub struct AppState {
    base_dir: RelativeFs,
    pub(crate) app_dir: PathBuf,
    pub buffer_items: usize,
    pub chunk_count: usize,
}

impl AppState {
    pub async fn browse_path(&self, path: &PortablePath) -> Result<Directory, Error> {
        let mut entries = self.base_dir.browse_path(path).await?;
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
        self.base_dir
            .write(
                &path,
                &form.file.into_vec().await.unwrap(),
                form.overwrite,
                &form.stats.0,
            )
            .await?;

        Ok(())
    }

    pub async fn delete_files(&self, paths: &[PortablePath]) -> Result<(), Error> {
        for path in paths {
            self.base_dir.delete_file(path).await?;
        }
        Ok(())
    }

    pub async fn read_file(&self, path: &PortablePath) -> Result<Vec<u8>, Error> {
        self.base_dir.read_file(path).await
    }

    pub async fn exchange_deltas(
        &self,
        tx: Sender<Vec<SyncItem>>,
        delta: shlib::DeltaExchange,
        chunk_size: usize,
    ) {
        self.base_dir.exchange_deltas(tx, delta, chunk_size).await
    }
}

impl TryFrom<&Args> for AppState {
    type Error = String;

    fn try_from(args: &Args) -> std::result::Result<Self, Self::Error> {
        let base_dir = args
            .base_dir
            .clone()
            .canonicalize()
            .map_err(|e| format!("Failed to canonicalize base_dir: {e}"))?;
        let app_dir = args
            .app_dir
            .clone()
            .canonicalize()
            .map_err(|e| format!("Failed to canonicalize app_dir: {e}"))?;

        // Ensure uploads directory exists
        if !base_dir.exists() {
            std::fs::create_dir_all(&base_dir)
                .map_err(|e| format!("Failed to create upload directory: {e}"))?;
        }
        Ok(AppState {
            base_dir: base_dir.into(),
            app_dir,
            buffer_items: args.buffer_items,
            chunk_count: args.chunk_count,
        })
    }
}
