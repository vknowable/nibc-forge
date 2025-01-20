use crate::error::AppError;
use crate::utils::list_resources;
use std::path::Path;

pub fn handle_list(args: crate::DeploymentArgs) -> Result<(), AppError> {
    println!("Listing created resources for deployment in directory: {}", args.deployment_dir);

    let deployment_dir = Path::new(&args.deployment_dir);
    let project_name = deployment_dir.file_name().unwrap().to_str().unwrap();

    list_resources("container", project_name)?;
    list_resources("network", project_name)?;
    list_resources("volume", project_name)?;

    Ok(())
}