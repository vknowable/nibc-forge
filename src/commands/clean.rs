use crate::error::AppError;
use crate::utils::deployment_compose_files;
use std::path::Path;
use std::process::Command;

pub fn handle_clean(args: crate::CleanArgs) -> Result<(), AppError> {
    println!(
        "Cleaning deployment in directory: {}. Wipe chain data: {}",
        args.deployment_dir, args.chain_data
    );
    
    let deployment_dir = Path::new(&args.deployment_dir);
    let project_name = deployment_dir.file_name().unwrap().to_str().unwrap();

    // Collect all docker-compose.yml files from subdirectories
    let compose_files = deployment_compose_files(deployment_dir)?;

    // First, run docker-compose down
    let mut down_command = Command::new("docker-compose");
    for compose_file in &compose_files {
        down_command.arg("-f").arg(compose_file.to_str().unwrap());
    }
    down_command
        .arg("--project-name")
        .arg(project_name)
        .arg("down")
        .arg("--volumes");

    let status = down_command.status().map_err(AppError::Io)?;

    if !status.success() {
        println!("docker-compose down failed with status code: {:?}", status.code());
        println!("You may need to manually stop and remove the containers associated with this deployment.");
    }

    // Manually clean all containers, networks, and volumes with label matching the project name
    clean_resources("container", project_name)?;
    clean_resources("network", project_name)?;
    clean_resources("volume", project_name)?;

    Ok(())
}

fn clean_resources(resource_type: &str, project_name: &str) -> Result<(), AppError> {
    println!("Cleaning {} resources for project: {}", resource_type, project_name);

    let label_filter = format!("label=com.docker.compose.project={}", project_name);
    let resources_output = Command::new("docker")
        .arg(resource_type)
        .arg("ls")
        .arg("--filter")
        .arg(&label_filter)
        .arg("--format")
        .arg("{{.ID}}") // Get only the resource IDs
        .output()
        .map_err(AppError::Io)?;

    let resource_ids_output = String::from_utf8_lossy(&resources_output.stdout);
    let resource_ids = resource_ids_output.lines().collect::<Vec<_>>();

    for id in resource_ids {
        let status = Command::new("docker")
            .arg(resource_type)
            .arg("rm")
            .arg("-f") // Force removal
            .arg(id)
            .status()
            .map_err(AppError::Io)?;

        if !status.success() {
            println!("Failed to remove {}: {}", resource_type, id);
        }
    }

    Ok(())
}