use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

use crate::errors::{ErrorCode, InstallError};

pub fn home_dir() -> Result<PathBuf, InstallError> {
    std::env::var("HOME")
        .map(PathBuf::from)
        .map_err(|_| InstallError::new(
            ErrorCode::HomeNotFound,
            "Could not determine the home directory",
            "Make sure $HOME is set in your environment.",
        ))
}

fn manifest_path() -> Option<PathBuf> {
    let home = std::env::var("HOME").ok()?;
    Some(PathBuf::from(home).join(".cache/surface-dots-installer/manifest.log"))
}

/// tack one line onto the install manifest. best-effort, i never let this fail a step.
pub fn log_action(action: &str, detail: &str) {
    if let Some(path) = manifest_path() {
        if let Some(parent) = path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(&path) {
            let _ = writeln!(f, "{action}\t{detail}");
        }
    }
}

/// copy a single file. text files get my /home/snes rewritten to your $HOME, binaries
/// copy as-is. keeps the original permissions.
pub fn copy_file(src: &Path, dest: &Path, error_code: ErrorCode) -> Result<(), InstallError> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|e| InstallError::new(
            error_code,
            format!("Could not create directory {}: {}", parent.display(), e),
            "Check write permissions.",
        ))?;
    }

    let home = home_dir()?;
    let home_str = home.to_string_lossy();

    let src_metadata = fs::metadata(src).map_err(|e| InstallError::new(
        error_code,
        format!("Failed to read metadata for {}: {}", src.display(), e),
        "Check that the file exists in the repo.",
    ))?;

    match fs::read_to_string(src) {
        Ok(content) => {
            let patched = content.replace("/home/snes", &home_str);
            fs::write(dest, patched).map_err(|e| InstallError::new(
                error_code,
                format!("Failed to write patched file {} -> {}: {}", src.display(), dest.display(), e),
                "Check that you have write access to the destination.",
            ))?;
        }
        Err(_) => {
            fs::copy(src, dest).map_err(|e| InstallError::new(
                error_code,
                format!("Failed to copy binary file {} -> {}: {}", src.display(), dest.display(), e),
                "Check that the file exists in the repo and that you have write access.",
            ))?;
        }
    }

    fs::set_permissions(dest, src_metadata.permissions()).map_err(|e| InstallError::new(
        error_code,
        format!("Failed to apply permissions to {}: {}", dest.display(), e),
        "Check your filesystem permissions.",
    ))?;

    log_action("COPY", &dest.to_string_lossy());
    Ok(())
}

/// copy everything under src into dest, recursively. skips anything ending in .old (those are backups).
pub fn copy_dir_contents(src: &Path, dest: &Path, error_code: ErrorCode) -> Result<(), InstallError> {
    fs::create_dir_all(dest).map_err(|e| InstallError::new(
        error_code,
        format!("Could not create destination directory {}: {}", dest.display(), e),
        "Check write permissions on the destination.",
    ))?;

    let entries = fs::read_dir(src).map_err(|e| InstallError::new(
        error_code,
        format!("Could not read source directory {}: {}", src.display(), e),
        "Check that the repository structure is intact.",
    ))?;

    for entry in entries {
        let entry = entry.map_err(|e| InstallError::new(error_code, e.to_string(), ""))?;
        let path = entry.path();
        let Some(name_os) = path.file_name() else { continue };
        let name = name_os.to_string_lossy();

        if name.ends_with(".old") {
            continue;
        }

        let dest_path = dest.join(name_os);

        if path.is_dir() {
            copy_dir_contents(&path, &dest_path, error_code)?;
        } else {
            copy_file(&path, &dest_path, error_code)?;
        }
    }
    Ok(())
}

fn backup_dir(dir: &Path, name: &str) -> PathBuf {
    dir.join(format!("{name}.old"))
}

/// if dir exists, stash its contents in <dir>/<name>.old before overwrite it.
pub fn backup_existing(dir: &Path, name: &str) -> Result<(), InstallError> {
    if !dir.exists() {
        return Ok(());
    }

    let backup = backup_dir(dir, name);

    if backup.exists() {
        fs::remove_dir_all(&backup).map_err(|e| InstallError::new(
            ErrorCode::BackupFailed,
            format!("Could not remove old backup at {}: {}", backup.display(), e),
            "Check permissions on the target directory.",
        ))?;
    }

    fs::create_dir_all(&backup).map_err(|e| InstallError::new(
        ErrorCode::BackupFailed,
        format!("Could not create backup directory: {e}"),
        "Check write permissions on the target directory.",
    ))?;

    copy_dir_contents(dir, &backup, ErrorCode::BackupFailed)?;
    log_action("BACKUP", &backup.to_string_lossy());
    Ok(())
}

/// back up dest first, then copy src in.
pub fn backup_and_install_dir(src: &Path, dest: &Path, name: &str, error_code: ErrorCode) -> Result<(), InstallError> {
    backup_existing(dest, name)?;
    copy_dir_contents(src, dest, error_code)?;
    Ok(())
}

/// put a component back from its <dir>/<name>.old backup, undoing an install.
/// runs when a step dies halfway so you're not left with a half-written config.
pub fn restore_backup(dir: &Path, name: &str) -> Result<(), InstallError> {
    let backup = backup_dir(dir, name);
    if !backup.exists() {
        return Ok(());
    }

    for entry in fs::read_dir(dir).map_err(|e| InstallError::new(
        ErrorCode::RollbackFailed,
        format!("Could not read {} during rollback: {}", dir.display(), e),
        "Restore the .old backup manually.",
    ))? {
        let Ok(entry) = entry else { continue };
        let path = entry.path();
        let Some(entry_name) = path.file_name().map(|n| n.to_string_lossy().into_owned()) else { continue };
        if entry_name == format!("{name}.old") {
            continue;
        }
        let _ = if path.is_dir() { fs::remove_dir_all(&path) } else { fs::remove_file(&path) };
    }

    copy_dir_contents(&backup, dir, ErrorCode::RollbackFailed)?;
    log_action("ROLLBACK", &dir.to_string_lossy());
    Ok(())
}
