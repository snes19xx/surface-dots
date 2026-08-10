use std::fs::{self, File, OpenOptions};
use std::io::{Read, Write};
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

/// Anything starting with a shebang gets +x. Some scripts went into git as 0644 and
/// a plain permission copy carries that straight through to the install.
fn make_executable_if_script(path: &Path) {
    use std::os::unix::fs::PermissionsExt;

    let mut head = [0u8; 2];
    match File::open(path).and_then(|mut f| f.read_exact(&mut head)) {
        Ok(()) if &head == b"#!" => {}
        _ => return,
    }

    if let Ok(meta) = fs::metadata(path) {
        let mut perms = meta.permissions();
        perms.set_mode(perms.mode() | 0o111);
        let _ = fs::set_permissions(path, perms);
    }
}

fn manifest_path() -> Option<PathBuf> {
    let home = std::env::var("HOME").ok()?;
    Some(PathBuf::from(home).join(".cache/surface-dots-installer/manifest.log"))
}

/// Append one action line to the install manifest. 
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

/// Copy one file. Text files get /home/snes rewritten to $HOME; binaries copy raw.
/// Original permissions are preserved.
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

    make_executable_if_script(dest);

    log_action("COPY", &dest.to_string_lossy());
    Ok(())
}

/// Copy everything inside src into dest, recursively. Skips any entry ending in .old.
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

/// If dir exists, back its contents up to <dir>/<name>.old before it gets overwritten.
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

/// Back up dest, then copy src into dest.
pub fn backup_and_install_dir(src: &Path, dest: &Path, name: &str, error_code: ErrorCode) -> Result<(), InstallError> {
    backup_existing(dest, name)?;
    copy_dir_contents(src, dest, error_code)?;
    Ok(())
}

/// Restore a component from its <dir>/<name>.old backup, reversing an install.
/// Used when a step fails partway so nothing is left half-written.
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
