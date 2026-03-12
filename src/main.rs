mod download;
mod github;
mod ui;

use anyhow::Result;
use clap::Parser;


#[derive(Parser)]
#[command(name = "ghgrab", version, about)]
struct Cli {
    url: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();
    ui::run_tui(cli.url).await?;
    Ok(())
}
