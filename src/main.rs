pub mod commands;
pub mod error;
pub mod config;
pub mod utils;

use clap::{Args, Parser, Subcommand};
use crate::commands::{create::handle_create, start::handle_start, stop::handle_stop, clean::handle_clean, list::handle_list, ibc_channels::handle_ibc_channels, dump_db::handle_dump_db};

#[derive(Parser)]
#[command(name = "nibc-forge")]
#[command(about = "Easily create and destroy local IBC testing deployments using Namada, Hermes, and supported Cosmos SDK chains", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a new deployment
    Create(CreateArgs),

    /// Start an existing deployment
    Start(DeploymentArgs),

    /// Stop a running deployment
    Stop(DeploymentArgs),

    /// Clean up deployment data
    Clean(DeploymentArgs),

    /// List containers, networks and volumes associated with a deployment
    List(DeploymentArgs),

    /// List the IBC channels of a deployment by querying the Hermes instance
    IbcChannels(DeploymentArgs),

    // TODO: Dump the Namada ledger contents to a toml file
    // DumpDb(DumpDbArgs),
}

#[derive(Args)]
pub struct CreateArgs {
    /// Path to the deployment configuration TOML file
    #[arg(long)]
    config_file: String,

    /// Directory where the deployment will be created
    #[arg(long)]
    deployment_dir: String,
}

#[derive(Args)]
pub struct DeploymentArgs {
    /// Directory of the deployment
    #[arg(long)]
    deployment_dir: String,
}

#[derive(Args)]
pub struct DumpDbArgs {
    /// Output file for the database dump (TOML format)
    #[arg(long)]
    output_file: String,
}

fn main() -> Result<(), error::AppError> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Create(args) => handle_create(args),
        Commands::Start(args) => handle_start(args),
        Commands::Stop(args) => handle_stop(args),
        Commands::Clean(args) => handle_clean(args),
        Commands::List(args) => handle_list(args),
        Commands::IbcChannels(args) => handle_ibc_channels(args),
        // Commands::DumpDb(args) => handle_dump_db(args),
    }
}
