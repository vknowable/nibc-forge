use std::path::{Path, PathBuf};
use std::fs;
use std::process::Command;
use crate::error::AppError;
use colored::Colorize;

pub const HERMES_TEMPLATE_DIR: &str = "hermes_templates";

pub fn deployment_compose_files(dir: &Path) -> Result<Vec<PathBuf>, AppError> {
    let mut compose_files = Vec::new();

    for entry in fs::read_dir(dir).map_err(AppError::Io)? {
        let entry = entry.map_err(AppError::Io)?;
        let subfolder = entry.path();
        if subfolder.is_dir() {
            let compose_file = subfolder.join("docker-compose.yml");
            if compose_file.exists() {
                compose_files.push(compose_file);
            }
        }
    }

    if compose_files.is_empty() {
        return Err(AppError::InvalidConfig(
            "No valid docker-compose.yml files found".into(),
        ));
    }

    Ok(compose_files)
}

pub fn list_resources(resource_type: &str, project_name: &str) -> Result<(), AppError> {
    println!("\n{}", format!("Deployment {}s:", resource_type).yellow().bold());

    let label_filter = format!("label=com.docker.compose.project={}", project_name);
    let label_format: &str = match resource_type {
        "container" => "{{.Names}}",
        _ => "{{.Name}}",
    };
    let resources_output = Command::new("docker")
        .arg(resource_type)
        .arg("ls")
        .arg("--filter")
        .arg(&label_filter)
        .arg("--format")
        .arg(label_format) // Get the resource names
        .output()
        .map_err(AppError::Io)?;

    if !resources_output.status.success() {
        eprintln!(
            "Failed to list {} for project {}: {}",
            resource_type,
            project_name,
            String::from_utf8_lossy(&resources_output.stderr)
        );
        return Err(AppError::DockerCommand("docker ls failed".into()));
    }

    let resource_names_output = String::from_utf8_lossy(&resources_output.stdout);
    let resource_names = resource_names_output.lines().collect::<Vec<_>>();
    if resource_names.len() == 0 {
        println!("None");
        return Ok(());
    }

    for name in resource_names {
        println!("{}", name);
    }

    Ok(())
}