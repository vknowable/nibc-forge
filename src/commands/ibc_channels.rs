use crate::error::AppError;
use serde_json::Value;
use std::path::Path;
use std::process::Command;
use colored::Colorize;

pub fn handle_ibc_channels(args: crate::DeploymentArgs) -> Result<(), AppError> {
    println!(
        "Listing created IBC channels for deployment in directory: {}",
        args.deployment_dir
    );

    let deployment_dir = Path::new(&args.deployment_dir);
    let project_name = deployment_dir.file_name().unwrap().to_str().unwrap();
    let hermes_container = format!("{}-hermes-1", project_name);

    // Channel json files are expected to be in /root/.hermes/ of Hermes container with filenames in the format ${chain_id_a}_${chain_id_b}.json
    let ls_output = Command::new("docker")
        .arg("exec")
        .arg(&hermes_container)
        .arg("sh")
        .arg("-c")
        .arg("ls /root/.hermes/*.json")
        .output()
        .map_err(AppError::Io)?;

    if !ls_output.status.success() {
        println!("No IBC channel JSON files found in Hermes container. NOTE: Channel creation may take several minutes per channel; wait a few minutes and try this command again.");
        return Err(AppError::DockerCommand(
            "Failed to list IBC JSON files in Hermes container".into(),
        ));
    }

    let json_files = String::from_utf8(ls_output.stdout)
        .map_err(|_| AppError::InvalidConfig("Non-UTF8 filenames found".into()))?
        .lines()
        .map(String::from)
        .collect::<Vec<_>>();

    if json_files.is_empty() {
        println!("No IBC channel JSON files found in Hermes container. NOTE: Channel creation may take several minutes per channel; wait a few minutes and try this command again.");
        return Ok(());
    }

    for json_file in json_files {
        // Extract chain IDs from the filename
        let filename = Path::new(&json_file)
            .file_name()
            .and_then(|name| name.to_str())
            .ok_or(AppError::InvalidConfig("Invalid JSON filename".into()))?;

        let (chain_a_id, chain_b_id) =
            filename
                .trim_end_matches(".json")
                .split_once('_')
                .ok_or(AppError::InvalidConfig(
                    "Invalid JSON filename format".into(),
                ))?;

        // Read the json file
        let cat_output = Command::new("docker")
            .arg("exec")
            .arg(&hermes_container)
            .arg("cat")
            .arg(&json_file)
            .output()
            .map_err(AppError::Io)?;

        if !cat_output.status.success() {
            println!("Failed to read file: {}", json_file);
            continue;
        }

        let file_contents = String::from_utf8(cat_output.stdout)
            .map_err(|_| AppError::InvalidConfig("Non-UTF8 JSON content".into()))?;

        // Parse json for channel and client IDs
        let parsed_json: Value = serde_json::from_str(&file_contents)
            .map_err(|_| AppError::InvalidConfig("Invalid JSON format".into()))?;

        let chain_a_channel = parse_json_value(&parsed_json, "/result/a_side/channel_id", "chain_a_channel")?;
        let chain_b_channel = parse_json_value(&parsed_json, "/result/b_side/channel_id", "chain_b_channel")?;
        let chain_a_client = parse_json_value(&parsed_json, "/result/a_side/client_id", "chain_a_client")?;
        let chain_b_client = parse_json_value(&parsed_json, "/result/b_side/client_id", "chain_b_client")?;
        let success = parse_json_value(&parsed_json, "/status", "success")?;

		let width = std::cmp::max(chain_a_id.len(), chain_b_id.len());

		println!("\n{}", format!(
			"{:<width$} {:^14} {:<width$}", 
			chain_a_id, "<------>", chain_b_id, 
			width = width)
			.yellow().bold()
		);
		println!(
			"{:<width$} {:^14} {:<width$}",
			chain_a_channel, "", chain_b_channel,
			width = width
		);
		println!(
			"{:<width$} {:^14} {:<width$}",
			chain_a_client, "", chain_b_client,
			width = width
		);
        match success {
            "success" => println!("Status: {}", "Success".green()),
            "error" => println!("Status: {}", "Failed".red()),
            _ => println!("Status: {}", "Unknown".yellow()),
        }
    }

    Ok(())
}

fn parse_json_value<'a>(
    json: &'a Value,
    pointer: &str,
    field_name: &str,
) -> Result<&'a str, AppError> {
    json.pointer(pointer)
        .and_then(Value::as_str)
        .ok_or_else(|| AppError::InvalidConfig(format!("Missing {} in JSON", field_name)))
}
