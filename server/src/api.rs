use std::sync::Arc;

use log::debug;
use poem::Result;
use poem::error::InternalServerError;
use poem::web::Data;
use poem_openapi::OpenApi;
use poem_openapi::payload::Attachment;
use poem_openapi::payload::AttachmentType;
use poem_openapi::payload::Json;
use poem_openapi::payload::PlainText;
use shlib::Directory;
use shlib::LookupResult;
use shlib::PortablePath;

use crate::app_state::AppState;
use crate::app_state::UploadFileRequest;
pub(crate) struct Api;

#[OpenApi]
impl Api {
    /// Hello world
    #[oai(path = "/test", method = "get")]
    async fn index(&self) -> PlainText<&'static str> {
        PlainText("Hello World")
    }

    /// List directory contents
    #[oai(path = "/browse/path", method = "post")]
    async fn list_directory(
        &self,
        config: Data<&Arc<AppState>>,
        path: Json<PortablePath>,
    ) -> Result<Json<Directory>> {
        debug!("Received path: {:?}", path.0);
        config
            .browse_path(&path)
            .await
            .map(Json)
            .map_err(InternalServerError)
    }

    /// Upload a file
    #[oai(path = "/upload/file", method = "post")]
    async fn upload_file(
        &self,
        config: Data<&Arc<AppState>>,
        form: UploadFileRequest,
    ) -> Result<PlainText<&'static str>> {
        config
            .save_uploaded_file(form)
            .await
            .map_err(InternalServerError)?;
        Ok(PlainText("File uploaded successfully!"))
    }

    #[oai(path = "/upload/check", method = "post")]
    async fn check_upload(
        &self,
        config: Data<&Arc<AppState>>,
        paths: Json<Vec<PortablePath>>,
    ) -> Result<Json<Vec<LookupResult>>> {
        let mut ret = Vec::new();
        for path in &paths.0 {
            ret.push(config.lookup(path).map_err(InternalServerError)?);
        }
        Ok(Json(ret))
    }

    #[oai(path = "/delete/files", method = "post")]
    async fn delete_files(
        &self,
        config: Data<&Arc<AppState>>,
        paths: Json<Vec<PortablePath>>,
    ) -> Result<PlainText<&'static str>> {
        config
            .delete_files(&paths.0)
            .await
            .map_err(InternalServerError)?;
        Ok(PlainText("Files deleted successfully!"))
    }

    #[oai(path = "/download/file", method = "post")]
    async fn download_file(
        &self,
        config: Data<&Arc<AppState>>,
        path: Json<PortablePath>,
    ) -> Result<Attachment<Vec<u8>>> {
        let file_data = config
            .read_file(&path.0)
            .await
            .map_err(InternalServerError)?;

        Ok(Attachment::new(file_data)
            .attachment_type(AttachmentType::Attachment)
            .filename(
                path.0
                    .components
                    .last()
                    .unwrap_or(&"downloaded_file".to_string()),
            ))
    }
}
