use std::path::PathBuf;

use log::debug;
use poem_openapi::Multipart;
use poem_openapi::types::multipart::JsonField;
use poem_openapi::types::multipart::Upload;
use shlib::Directory;
use shlib::Error;
use shlib::LookupResult;
use shlib::PortablePath;
use shlib::RelativeFs;

use crate::args::Args;

// Define a struct to represent the multipart form data, including the file.
#[derive(Debug, Multipart)]
pub(crate) struct UploadFileRequest {
    #[oai(rename = "file")] // Rename the field to "file" in the form data
    file: Upload, // Represents the uploaded file
    description: String,           // Additional field in the form
    path: JsonField<PortablePath>, // Path where the file should be uploaded
    overwrite: bool,               // Whether to overwrite existing files
    sha256: Option<String>,        // Optional checksum field
}

pub struct AppState {
    base_dir: RelativeFs,
    pub(crate) app_dir: PathBuf,
}

impl AppState {
    pub fn lookup(&self, path: &PortablePath) -> Result<LookupResult, Error> {
        path.lookup()
    }

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
        // In a real application, you would save the file to disk or cloud storage here.
        // For this example, we just print some information.
        debug!(
            "Received file: {filename} Content-Type: {content_type} Description: {} Upload path: {} sha256: {:?}",
            form.description, form.path.0, form.sha256
        );
        let mut path = form.path.0.clone();
        path.push(filename);

        self.base_dir
            .write(&path, &form.file.into_vec().await.unwrap(), form.overwrite)
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
        })
    }
}
