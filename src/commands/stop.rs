use crate::error::AppError;
use crate::utils::deployment_compose_files;
use std::path::Path;
use std::process::Command;

pub fn handle_stop(args: crate::DeploymentArgs) -> Result<(), AppError> {
    println!("Stopping deployment in directory: {}", args.deployment_dir);

    let deployment_dir = Path::new(&args.deployment_dir);
    let project_name = deployment_dir.file_name().unwrap().to_str().unwrap();

    // Collect all docker-compose.yml files from subdirectories
    let compose_files = deployment_compose_files(deployment_dir)?;

    // Stop running containers associated with this deployment
    let mut stop_command = Command::new("docker-compose");
    for compose_file in &compose_files {
        stop_command.arg("-f").arg(compose_file.to_str().unwrap());
    }
    stop_command
        .arg("--project-name")
        .arg(project_name)
        .arg("stop");

    let status = stop_command.status().map_err(AppError::Io)?;

    if !status.success() {
        println!("Error stopping deployment. You may wish to run `nibc-forge clean` to remove any associated docker containers, networks, and/or volumes.");
        return Err(AppError::DockerCommand("docker-compose down failed".into()));
    }

    Ok(())
}
