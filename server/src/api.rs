use std::sync::Arc;

use log::debug;
use poem::Result;
use poem::error::InternalServerError;
use poem::web::Data;
use poem_openapi::OpenApi;
use poem_openapi::payload::Attachment;
use poem_openapi::payload::AttachmentType;
use poem_openapi::payload::EventStream;
use poem_openapi::payload::Json;
use poem_openapi::payload::PlainText;
use shlib::DeltaExchange;
use shlib::Directory;
use shlib::PortablePath;
use shlib::SyncItem;
use tokio::sync::mpsc;
use tokio_stream::wrappers::ReceiverStream;

use crate::app_state::AppState;
use crate::app_state::UploadFileRequest;
pub(crate) struct Api;

static API_VERSION: &str = "1";

#[OpenApi]
impl Api {
    /// Hello world
    #[oai(path = "/test", method = "get")]
    async fn index(&self) -> PlainText<&'static str> {
        debug!("Received test request");
        PlainText("Hello World")
    }

    /// Return the version of the server
    /// This can be used by clients to check compatibility.
    #[oai(path = "/server_version", method = "get")]
    async fn version(&self) -> PlainText<&'static str> {
        debug!("Received version request");
        PlainText(env!("CARGO_PKG_VERSION"))
    }

    /// Return the api version of the server
    /// This can be used by clients to check compatibility.
    #[oai(path = "/api_version", method = "get")]
    async fn api_version(&self) -> PlainText<&'static str> {
        debug!("Received api version request");
        PlainText(API_VERSION)
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

    /// Exchange deltas with the server.
    /// recursively traverses a directory tree at `path` and returns a list of
    /// all files found, along with their metadata including checksum.
    /// Input SyncData can be null for server to send full SyncData.
    #[oai(path = "/browse/exchange_deltas", method = "post")]
    async fn exchange_deltas(
        &self,
        config: Data<&Arc<AppState>>,
        delta: Json<DeltaExchange>,
    ) -> EventStream<ReceiverStream<Vec<SyncItem>>> {
        debug!("exchange_deltas SyncItem: {:?}", delta.0);
        let (tx, rx) = mpsc::channel(config.buffer_items);
        let state = config.0.clone();
        tokio::spawn(async move {
            state.exchange_deltas(tx, delta.0, state.chunk_count).await;
        });
        let rx_stream = ReceiverStream::new(rx);
        EventStream::new(rx_stream)
    }

    /// Upload a file
    #[oai(path = "/upload/file", method = "post")]
    async fn upload_file(
        &self,
        config: Data<&Arc<AppState>>,
        form: UploadFileRequest,
    ) -> Result<PlainText<&'static str>> {
        debug!("Received upload request for path: {:?}", form.path.0);
        config
            .save_uploaded_file(form)
            .await
            .map_err(InternalServerError)?;
        Ok(PlainText("File uploaded successfully!"))
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
            .filename(path.0.basename().unwrap_or("downloaded_file")))
    }
}
