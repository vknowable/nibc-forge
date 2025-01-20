use serde::Deserialize;

#[derive(Deserialize)]
pub struct ModuleConfig {
    pub module_dir: String,
    #[serde(rename = "type")]
    pub _type: String,
    pub rpc_hostname: Option<String>,
    pub relayer_key: Option<String>,
    pub hermes_template: Option<String>,
    pub docker_env: Option<String>,
}

#[derive(Deserialize)]
pub struct Config {
    pub modules: Vec<ModuleConfig>,
}