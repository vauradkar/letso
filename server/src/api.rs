use std::sync::Arc;

use log::debug;
use pfs::Directory;
use pfs::FileInfo;
use pfs::Path;
use pfs::RecursiveDirList;
use poem::Result;
use poem::error::InternalServerError;
use poem::web::Data;
use poem_openapi::OpenApi;
use poem_openapi::payload::Attachment;
use poem_openapi::payload::AttachmentType;
use poem_openapi::payload::EventStream;
use poem_openapi::payload::Json;
use poem_openapi::payload::PlainText;
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
        path: Json<Path>,
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
        delta: Json<RecursiveDirList>,
    ) -> EventStream<ReceiverStream<Vec<FileInfo>>> {
        debug!("exchange_deltas FileInfo: {:?}", delta.0);
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
        paths: Json<Vec<Path>>,
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
        path: Json<Path>,
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

#[cfg(test)]
mod tests {
    use std::path::Path as StdPath;
    use std::sync::Arc;

    use pfs::FileNode;
    use pfs::RecursiveDirList;
    use pfs::TestRoot;
    use poem::EndpointExt;
    use poem::Route;
    use poem::middleware::AddDataEndpoint;
    use poem::middleware::Tracing;
    use poem::middleware::TracingEndpoint;
    use poem::test::TestClient;
    use poem::test::TestForm;
    use poem::test::TestFormField;
    use poem_openapi::OpenApiService;
    use tempdir::TempDir;

    use super::*;
    use crate::app_state::AppState;
    use crate::args::Args;

    async fn setup_app() -> (
        TempDir,
        TestClient<AddDataEndpoint<TracingEndpoint<Route>, Arc<AppState>>>,
    ) {
        let temp_dir = TempDir::new("").unwrap();
        let client = setup_app_with_dir(temp_dir.path()).await;
        (temp_dir, client)
    }

    async fn setup_app_with_dir(
        temp_dir: &StdPath,
    ) -> TestClient<AddDataEndpoint<TracingEndpoint<Route>, Arc<AppState>>> {
        let app_state = Arc::new(
            AppState::try_from(&Args {
                upload_root: temp_dir.to_path_buf(),
                ui_dir: None,
                bind: "localhost".into(),
                port: 8080,
                buffer_items: 10,
                chunk_count: 5,
            })
            .unwrap(),
        );
        if let Err(e) = tracing_subscriber::fmt()
            .with_env_filter("poem=warn")
            .try_init()
        {
            println!("tracing maybe initialized by other test. Err: {}", e);
        }
        // Create the API instance
        let api_service = OpenApiService::new(Api, "Hello World", "1.0");
        let app = Route::new()
            .nest("/api", api_service)
            .with(Tracing)
            .data(app_state);
        TestClient::new(app)
    }

    async fn upload_file(
        client: &TestClient<AddDataEndpoint<TracingEndpoint<Route>, Arc<AppState>>>,
        file_path: &str,
        dest_path: &Path,
        overwrite: bool,
        file_rep: &FileNode,
    ) -> poem::test::TestResponse {
        let filename = StdPath::new(file_path)
            .file_name()
            .unwrap()
            .to_str()
            .unwrap();

        let stats_json = serde_json::to_string(&file_rep.stats).unwrap();

        client
            .post("/api/upload/file")
            .multipart(
                TestForm::new()
                    .field(
                        TestFormField::bytes(file_rep.contents.as_slice())
                            .filename(filename)
                            .name("file"),
                    )
                    .text("path", serde_json::to_string(dest_path).unwrap())
                    .text("overwrite", overwrite.to_string())
                    .text("stats", stats_json),
            )
            .send()
            .await
    }

    #[tokio::test]
    async fn test_upload_file() {
        let local_root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let (remote_root, client) = setup_app().await;

        for (relative_path, file_rep) in &local_root.files {
            if file_rep.stats.is_directory {
                continue;
            }

            let dest = if let Some(parent) = relative_path.parent() {
                Path::try_from(&parent.to_owned()).unwrap()
            } else {
                let fpath: &[&str] = &[];
                Path::try_from(fpath).unwrap()
            };
            let response = upload_file(
                &client,
                &local_root.root.path().join(relative_path).to_string_lossy(),
                &dest,
                true,
                file_rep,
            )
            .await;
            response.assert_status_is_ok();
            let response_text = response.0.into_body().into_string().await.unwrap();
            assert_eq!(response_text, "File uploaded successfully!");
        }

        let diff = local_root.compare(remote_root.path()).unwrap();
        assert!(
            diff.is_none(),
            "local and remote dir diff:\n{}",
            diff.unwrap()
        );

        // Verify the file was saved
        for (relative_path, file_rep) in &local_root.files {
            println!(
                "Verifying uploaded file: {} {:?}",
                relative_path.display(),
                file_rep.stats
            );
            if file_rep.stats.is_directory {
                continue;
            }

            let uploaded_file_path = remote_root.path().join(relative_path);
            assert!(uploaded_file_path.exists());
            let found = tokio::fs::read(&uploaded_file_path).await.unwrap();
            assert_eq!(found, file_rep.contents);
        }
    }

    #[tokio::test]
    async fn test_are_synced() {
        let local_root = TestRoot::new(std::thread::current().name()).await.unwrap();
        let client = setup_app_with_dir(local_root.root.path()).await;

        let mut deltas = vec![];
        for (relative_path, file_rep) in &local_root.files {
            let pp = Path::try_from(relative_path).unwrap();
            deltas.push(FileInfo {
                path: pp,
                stats: file_rep.stats.clone(),
            });
        }
        let response = client
            .post("/api/browse/exchange_deltas")
            .body_json(&RecursiveDirList {
                base_dir: Path::try_from(&[] as &[&str]).unwrap(),
                deltas,
            })
            .send()
            .await;
        response.assert_status_is_ok();
        let stream = response.0.into_body().into_string().await.unwrap();
        assert_eq!(stream, "");
    }
}
