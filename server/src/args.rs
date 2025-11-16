use std::path::PathBuf;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Args {
    /// Where the files are uploaded to or displayed from.
    #[arg(short = 'r', long)]
    pub upload_root: PathBuf,

    /// Static html directory to serve.
    #[arg(short, long)]
    pub ui_dir: Option<PathBuf>,

    /// Host/bind address.
    /// Defaults to localhost.
    #[arg(short, long, default_value_t = String::from("localhost"))]
    pub bind: String,

    /// Port to listen on.
    /// Defaults to 3000.
    #[arg(short, long, default_value_t = 3000)]
    pub port: u16,

    /// Number of items to buffer when uploading/downloading files.
    #[arg(long, default_value_t = 1000)]
    pub buffer_items: usize,

    /// Number of chunks to split files into for REST api transfer.
    #[arg(short, long, default_value_t = 1000)]
    pub chunk_count: usize,
}
