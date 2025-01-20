use thiserror::Error;

#[derive(Error, Debug)]
pub enum AppError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Docker command failed: {0}")]
    DockerCommand(String),

    #[error("Invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("Unknown error occurred")]
    Unknown,
}
