use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use colored::Colorize;
use serde_json::json;
use toml_edit::{value, DocumentMut, Item};

use crate::config::{Config, ModuleConfig};
use crate::utils::HERMES_TEMPLATE_DIR;
use crate::error::AppError;

pub fn handle_create(args: crate::CreateArgs) -> Result<(), AppError> {
    println!(
        "Creating deployment with config file: {} and deployment dir: {}",
        args.config_file, args.deployment_dir
    );

    // Parse the config file
    let config_content = fs::read_to_string(&args.config_file)
        .map_err(|_| AppError::InvalidConfig("Failed to read config file".to_string()))?;
    let config: Config = toml::from_str(&config_content)
        .map_err(|_| AppError::InvalidConfig("Invalid config file format".to_string()))?;


    // Check if deployment dir exists
    let deployment_dir = Path::new(&args.deployment_dir);
    if deployment_dir.exists() {
        return Err(AppError::InvalidConfig(format!(
            "Deployment directory already exists: {}",
            args.deployment_dir
        )));
    }

    let mut validation_errors = Vec::new();
    let mut validation_warnings = Vec::new();

    // Check for exactly one module of type hermes
    let hermes_modules: Vec<&ModuleConfig> = config
        .modules
        .iter()
        .filter(|module| module._type == "hermes")
        .collect();
    if hermes_modules.len() > 1 {
        return Err(AppError::InvalidConfig(
            "Config cannot include more than one Hermes module".to_string(),
        ));
    } else if hermes_modules.is_empty() {
        validation_warnings.push("no Hermes module in config; is this intended? (If so, ignore this warning)".to_string());
    }

    // Validate module and Hermes template paths given in config file
    for module in &config.modules {
        let module_src = Path::new(&module.module_dir);
        if !module_src.exists() {
            validation_errors.push(format!(
                "Module directory not found: {}",
                module_src.display()
            ));
        }

        if module._type != "aux" {
            // If no Hermes template provided, fallback to hermes_templates/{chain-type}.toml
            let template_src = match &module.hermes_template {
                Some(path) => Path::new(path).to_path_buf(),
                None => {
                    let fallback_msg = format!("hermes_template not specified for module {}; falling back to default value hermes_templates/{}", &module.module_dir, &module._type);
                    println!("{} {}", format!("WARNING: ").yellow().bold(), fallback_msg);
                    Path::new(HERMES_TEMPLATE_DIR).join(format!("{}.toml", &module._type))
                }
            };
            if !template_src.exists() {
                validation_errors.push(format!(
                    "Hermes template {} not found for module {}",
                    template_src.display(),
                    module_src.display()
                ));
            }
        }
    }

    // Ensure unique hostnames and module_dirs
    // TODO: this is a temporary solution until a strategy to handle multiple copies of the same module is in place
    let mut seen_hostnames = HashSet::new();
    let mut seen_module_dirs = HashSet::new();
    for module in &config.modules {
        if let Some(hostname) = &module.rpc_hostname {
            if !seen_hostnames.insert(hostname) {
                validation_errors.push("All modules must have a unique hostname".to_string());
            }
        }
        if !seen_module_dirs.insert(&module.module_dir) {
            validation_errors.push("All modules must have a unique module_dir".to_string());
        }
    }

    // TODO: check docker compose files for conflicting host ports, volume names, service names, or docker hostnames
    // // Check for conflicts in docker-compose.yml
    // let mut resource_map: HashMap<String, HashSet<String>> = HashMap::new();
    // for module in &config.modules {
    //     let compose_path = Path::new(&module.module_dir).join("docker-compose.yml");
    //     if compose_path.exists() {
    //         let content = fs::read_to_string(&compose_path).unwrap_or_default();
    //         for line in content.lines() {
    //             if let Some(resource) = extract_docker_resource(line) {
    //                 resource_map
    //                     .entry(resource.clone())
    //                     .or_default()
    //                     .insert(module.module_dir.clone());
    //             }
    //         }
    //     }
    // }
    // for (resource, dirs) in resource_map {
    //     if dirs.len() > 1 {
    //         validation_warnings.push(format!(
    //             "Docker Resource conflict for {} between: {}",
    //             resource,
    //             dirs.into_iter().collect::<Vec<_>>().join(", ")
    //         ));
    //     }
    // }

    // Filter chain modules and validate relayer_key presence
    let chain_modules: Vec<&ModuleConfig> = config
        .modules
        .iter()
        .filter(|module| module._type != "aux" && module._type != "hermes")
        .collect();
    for module in &chain_modules {
        if module.relayer_key.is_none() || module.relayer_key == Some("".to_string()) {
            validation_errors.push(format!(
                "Relayer key not provided for {}",
                module.module_dir
            ));
        }
    }

    if !validation_errors.is_empty() {
        println!("{}", format!("Validation failed with the following errors:").red().bold());
        return Err(AppError::InvalidConfig(format!(
            "{}",
            validation_errors.join("; ")
        )));
    }

    // Create the deployment directory
    fs::create_dir_all(deployment_dir).map_err(AppError::Io)?;

    // Copy the module directories to the deployment directory
    for module in &config.modules {
        let module_src = format!("{}", module.module_dir);
        let module_subdir = Path::new(&module_src).file_name().unwrap().to_str().unwrap();
        let module_dst = deployment_dir.join(module_subdir);
        copy_dir_recursively(&module_src, &module_dst)?;

        // Write docker_env variables to the module's .env file
        if let Some(variable_list) = &module.docker_env {
            let env_variables = variable_list.replace(',', "\n");
            let env_file_path = module_dst.join(".env");

            fs::write(&env_file_path, env_variables).map_err(|err| {
                AppError::InvalidConfig(format!(
                    "Failed to write .env file to {}: {}",
                    env_file_path.display(), err
                ))
            })?;
        }
    }

    // If a hermes module is present, generate the required chainlist.json and hermes config.toml files based on the other included modules
    let hermes_module = config.modules.iter().find(|module| module._type == "hermes");
    if let Some(hermes) = hermes_module {
        match Path::new(&hermes.module_dir).file_name() {
            Some(hermes_dir) => {
                let json_output_path = Path::new(deployment_dir)
                    .join(&hermes_dir)
                    .join("chainlist.json");
                generate_chainlist_json(&chain_modules, json_output_path)?;

                let config_output_path = Path::new(deployment_dir)
                    .join(&hermes_dir)
                    .join("config.toml");
                generate_config_toml(&hermes, &chain_modules, config_output_path)?;
            }
            None => return Err(AppError::Unknown)
        }

    // let config_output_path = {deployment_dir}/{module_dir}/config.toml
    // let output_toml = []
    // construct the final toml by starting with the hermes module hermes_template toml and appending the hermes_template for each chain
    // load toml hermes_module.hermes_template and push to output_toml
    // for each module in chain_modules:
    // load the toml for module.hermes_template
    // edit the following keys (in memory, leave original file untouched):
    // id = 'CHAIN_{current_index}'
    // rpc_addr = 'http://HOST_{current_index}:26657'
    // grpc_addr = 'http://HOST_{current_index}:9090'
    // event_source = { mode = 'push', url = 'ws://HOST_{current_index}:26657/websocket', batch_delay = '500ms' }
    // key_name = 'KEY_{current_index}'
    // gas_price.denom = 'DENOM_{current_index}'
    // push edited toml contents to output_toml
    // end for loop
    // write output_toml to config_output_path

    }

    if !validation_warnings.is_empty() {
        println!("Deployment will be created however the following issues may need to be addressed before it can be started:");
    }
    for warning in validation_warnings {
        println!("{} {}", format!("WARNING: ").yellow().bold(), warning);
    }

    println!("Deployment created successfully!");
    Ok(())
}

fn copy_dir_recursively(src: &str, dst: &Path) -> Result<(), AppError> {
    // Ensure the destination directory exists
    fs::create_dir_all(dst).map_err(AppError::Io)?;

    for entry in fs::read_dir(src).map_err(|err| {
        if err.kind() == std::io::ErrorKind::NotFound {
            AppError::InvalidConfig(format!("Directory not found: {}", src))
        } else {
            AppError::Io(err)
        }
    })? {
        let entry = entry.map_err(AppError::Io)?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());

        if src_path.is_dir() {
            copy_dir_recursively(src_path.to_str().unwrap(), &dst_path)?; // Recurse for directories
        } else {
            fs::copy(&src_path, &dst_path).map_err(|err| {
                if err.kind() == std::io::ErrorKind::NotFound {
                    AppError::InvalidConfig(format!("File not found: {}, {}", src_path.display(), dst_path.display()))
                } else {
                    AppError::Io(err)
                }
            })?; // Copy files
        }
    }
    Ok(())
}

// fn extract_docker_resource(line: &str) -> Option<String> {
//     // Simplified placeholder
//     if line.contains("hostname:") {
//         Some(line.trim().to_string())
//     } else {
//         None
//     }
// }

fn generate_chainlist_json(modules: &Vec<&ModuleConfig>, output_path: PathBuf) -> Result<(), AppError> {
    let mut chain_json = Vec::new();

    for module in modules {
        if let (Some(hostname), Some(relayer_key)) = (&module.rpc_hostname, &module.relayer_key) {
            chain_json.push(json!({
                "hostname": hostname,
                "key": relayer_key,
                "type": module._type,
            }));
        } else {
            return Err(AppError::InvalidConfig(format!(
                "Missing required fields for module: {}; both rpc_hostname and relayer_key must be specified for chain-type modules",
                module.module_dir
            )));
        }
    }

    // Write the chain_json to the file
    let json_content = serde_json::to_string_pretty(&chain_json).map_err(|err| {
        AppError::InvalidConfig(format!("Failed to serialize JSON: {}", err))
    })?;

    fs::write(&output_path, json_content).map_err(|err| {
        AppError::InvalidConfig(format!(
            "Failed to write chainlist.json to {}: {}",
            output_path.display(), err
        ))
    })?;

    println!("Generated chainlist.json at {}", output_path.display());

    Ok(())
}

fn generate_config_toml(
    hermes_module: &ModuleConfig,
    chain_modules: &Vec<&ModuleConfig>,
    output_path: PathBuf,
) -> Result<(), AppError> {
    // Load the base Hermes template
    let mut output_toml_content = fs::read_to_string(&hermes_module.hermes_template.as_ref().ok_or_else(|| {
        AppError::InvalidConfig(format!(
            "Hermes module {} missing template",
            &hermes_module.module_dir
        ))
    })?)?;

    // Process each chain module and append its modified template
    for (index, module) in chain_modules.iter().enumerate() {
        let chain_template_path = module.hermes_template.as_ref().ok_or_else(|| {
            AppError::InvalidConfig(format!(
                "Module {} missing Hermes template",
                &module.module_dir
            ))
        })?;

        let chain_toml_content =
            fs::read_to_string(chain_template_path).map_err(|_| {
                AppError::InvalidConfig(format!(
                    "Failed to read Hermes template for module {}",
                    &module.module_dir
                ))
            })?;

        let mut chain_doc: DocumentMut = chain_toml_content
            .parse()
            .map_err(|_| AppError::InvalidConfig("Failed to parse chain template".to_string()))?;

        // Update the template with these placeholder values. The Hermes initialization script expects these, numbered according to the chain
        let host_placeholder = format!("HOST_{index}");
        let key_placeholder = format!("KEY_{index}");
        let denom_placeholder = format!("DENOM_{index}");
        let chain_id_placeholder = format!("CHAIN_{index}");

        // Access the `[[chains]]` array (we iterate here but this array is expected to contain only a single item)
        if let Item::ArrayOfTables(chains) = &mut chain_doc["chains"] {
            for chain in chains.iter_mut() {
                chain["id"] = value(chain_id_placeholder.clone());
                chain["rpc_addr"] = value(format!("http://{}:26657", host_placeholder));
                chain["grpc_addr"] = value(format!("http://{}:9090", host_placeholder));
                chain["event_source"]["url"] = value(format!("ws://{}:26657/websocket", host_placeholder));
                chain["gas_price"]["denom"] = value(denom_placeholder.clone());
                chain["key_name"] = value(key_placeholder.clone());
            }
        }

        output_toml_content += format!("\n{}", &chain_doc.to_string()).as_str();
    }

    // Write the final output toml to the config file
    fs::write(&output_path, output_toml_content).map_err(|err| {
        AppError::InvalidConfig(format!(
            "Failed to write config.toml to {}: {}",
            output_path.display(), err
        ))
    })?;

    println!("Generated intermediate Hermes config at {}", output_path.display());

    Ok(())
}