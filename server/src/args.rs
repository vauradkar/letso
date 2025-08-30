use std::path::PathBuf;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Args {
    /// Where the files are uploaded to or displayed from.
    #[arg(short = 'r', long)]
    pub base_dir: PathBuf,

    /// Static html directory to serve.
    #[arg(short, long)]
    pub app_dir: PathBuf,

    /// Host/bind address.
    /// Defaults to localhost.
    #[arg(short, long, default_value_t = String::from("localhost"))]
    pub bind: String,

    /// Port to listen on.
    /// Defaults to 3000.
    #[arg(short, long, default_value_t = 3000)]
    pub port: u16,
}
