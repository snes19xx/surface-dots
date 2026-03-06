/// All error codes are prime numbers :)
#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
#[repr(u32)]
pub enum ErrorCode {
    Unknown            = 2,
    RepoNotFound       = 3,
    HomeNotFound       = 5,
    BackupFailed       = 7,
    HyprMainFailed     = 11,
    HyprPatchFailed    = 13,
    HyprShadersFailed  = 17,
    HyprScriptsFailed  = 19,
    HyprLockFailed     = 23,
    KittyFailed        = 29,
    GtkFailed          = 31,
    KvantumFailed      = 37,
    DunstFailed        = 41,
    RofiFailed         = 43,
    UtilsFailed        = 47,
    QuickshellFailed   = 53,
    SddmSourceNotFound = 59,
    SddmCopyFailed     = 61,
    SddmConfDirFailed  = 67,
    SddmDefaultFailed  = 71,
    InvalidResolution  = 73,
    InvalidScale       = 79,
}

/// Serialised over the Tauri IPC bridge:
#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct InstallError {
    pub code: u32,
    pub message: String,
    pub hint: String,
}

impl InstallError {
    pub fn new(code: ErrorCode, message: impl Into<String>, hint: impl Into<String>) -> Self {
        Self {
            code: code as u32,
            message: message.into(),
            hint: hint.into(),
        }
    }
}
