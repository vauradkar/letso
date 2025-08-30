//! Crate-level documentation: Server main module for file browsing
//! functionality.

use std::sync::Arc;

use clap::Parser;
use log::info;
use poem::EndpointExt;
use poem::Route;
use poem::Server;
use poem::endpoint::StaticFilesEndpoint;
use poem::listener::TcpListener;
use poem::middleware::Tracing;
use poem_openapi::OpenApiService;

mod api;
use crate::api::Api;

mod app_state;
use crate::app_state::AppState;

mod args;
use crate::args::Args;

mod errors;

static API_ROOT: &str = "/api";
static DOCS_ROOT: &str = "/docs";

#[tokio::main]
async fn main() {
    env_logger::init();
    let args = Args::parse();
    let config = AppState::try_from(&args).expect("Invalid configuration");

    let bind_address = format!("{}:{}", args.bind, args.port);
    let server = format!("http://{bind_address}");
    let api_root = format!("{server}{API_ROOT}");
    info!("Starting:    server at {server}");
    info!("             api root at {api_root}");
    info!("             docs root at {server}{DOCS_ROOT}");

    let api_service = OpenApiService::new(Api, "Hello World", "1.0").server(api_root);
    let ui = api_service.swagger_ui();
    let static_endpoint = StaticFilesEndpoint::new(config.app_dir.clone()).index_file("index.html");
    let app = Route::new()
        .nest(API_ROOT, api_service)
        .nest("/", static_endpoint)
        .nest(DOCS_ROOT, ui)
        .with(Tracing)
        .data(Arc::new(config));

    Server::new(TcpListener::bind(bind_address))
        .run(app)
        .await
        .unwrap();
}
