use crate::error::AppError;
use crate::utils::{deployment_compose_files, list_resources};
use std::path::Path;
use std::process::{Command, Stdio};

pub fn handle_start(args: crate::DeploymentArgs) -> Result<(), AppError> {
    println!("Starting deployment in directory: {}", args.deployment_dir);

    let deployment_dir = Path::new(&args.deployment_dir);
    let project_name = deployment_dir.file_name().unwrap().to_str().unwrap();

    // Collect all docker-compose.yml files from subdirectories
    let compose_files = deployment_compose_files(deployment_dir)?;

    // Check for running containers associated with this deployment
    let mut ps_command = Command::new("docker");
    ps_command.arg("compose");
    for compose_file in &compose_files {
        ps_command.arg("-f").arg(compose_file.to_str().unwrap());
    }
    ps_command.arg("ps").arg("-q");

    let ps_output = ps_command.output().map_err(AppError::Io)?;

    if !ps_output.stdout.is_empty() {
        println!("Deployment already running.");
        return Ok(());
    }

    // Start deployment. We start each compose file in a separate command to avoid issues with relative paths in the compose files
    for compose_file in compose_files.iter() {
        println!("Using compose file: {}", compose_file.display());

        let mut up_command = Command::new("docker");
        up_command.arg("compose");
        up_command
            .arg("-f")
            .arg(compose_file.to_str().unwrap())
            .arg("--project-name")
            .arg(project_name)
            .arg("up")
            .arg("-d");

        // Suppress stderr output to hide the irrelevant warnings about orphaned containers
        let status = up_command.stderr(Stdio::null()).status().map_err(AppError::Io)?;

        if !status.success() {
            println!("Failed to start components for compose file: {}. Is there a name, resource or port conflict with another module or a previous deployment?", compose_file.display());
            println!("You can also run `nibc-forge clean` to remove any associated docker containers, networks, and/or volumes and try again.");
            return Err(AppError::DockerCommand(
                format!("docker compose up failed for {}", compose_file.display()).into(),
            ));
        }

        println!("Successfully started components for compose file: {}", compose_file.display());
    }

    // List all resources created by the deployment
    list_resources("container", project_name)?;
    list_resources("network", project_name)?;
    // list_resources("volume", project_name)?; // TODO: listing volumes by project_name is not supported

    println!("\nCreating the IBC channels may take several minutes. Follow the logs of the Hermes container to monitor the progress.");

    Ok(())
}
