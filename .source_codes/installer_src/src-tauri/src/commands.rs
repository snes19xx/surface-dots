use std::fs::{self, File};
use std::path::PathBuf;
use std::process::Command;

use flate2::read::GzDecoder;
use tar::Archive;

use crate::errors::{ErrorCode, InstallError};
use crate::fs_ops::{backup_and_install_dir, backup_existing, copy_dir_contents, copy_file, home_dir, restore_backup};
use crate::hypr::{self, MonitorInput};
use crate::preflight::{self, PreflightReport};
use crate::{paths, sddm};

#[tauri::command]
pub fn get_repo_root() -> Result<String, InstallError> {
    paths::find_repo_root()
        .map(|p| p.to_string_lossy().into_owned())
        .ok_or_else(|| InstallError::new(
            ErrorCode::RepoNotFound,
            "Could not locate the surface-dots repository",
            "Run the installer from inside the surface-dots repository. If you moved the binary, \
             place it back inside the repo tree and try again.",
        ))
}

#[tauri::command]
pub fn preflight(repo_root: String) -> PreflightReport {
    preflight::run(&repo_root)
}

#[tauri::command]
pub fn configure_monitors(
    repo_root: String,
    primary: MonitorInput,
    secondary: Option<MonitorInput>,
) -> Result<(), InstallError> {
    let result = hypr::configure_monitors(&repo_root, primary, secondary);
    if result.is_err() {
        let _ = hypr::rollback_hypr();
    }
    result
}

#[tauri::command]
pub fn copy_hypr_item(repo_root: String, item: String) -> Result<(), InstallError> {
    let result = hypr::copy_hypr_item(&repo_root, &item);
    if result.is_err() {
        let _ = hypr::rollback_hypr();
    }
    result
}

#[tauri::command]
pub fn copy_config_item(repo_root: String, item: String) -> Result<(), InstallError> {
    let home = home_dir()?;
    let repo_config = PathBuf::from(&repo_root).join(".config");
    let dest_config = home.join(".config");

    match item.as_str() {
        "kitty" => backup_and_install_dir(
            &repo_config.join("kitty"),
            &dest_config.join("kitty"),
            "kitty",
            ErrorCode::KittyFailed,
        )
        .inspect_err(|_| { let _ = restore_backup(&dest_config.join("kitty"), "kitty"); }),

        "gtk" => install_gtk(&repo_config, &home),

        "kvantum" => backup_and_install_dir(
            &repo_config.join("kvantum"),
            &dest_config.join("kvantum"),
            "kvantum",
            ErrorCode::KvantumFailed,
        )
        .inspect_err(|_| { let _ = restore_backup(&dest_config.join("kvantum"), "kvantum"); }),

        "dunst" => backup_and_install_dir(
            &repo_config.join("dunst"),
            &dest_config.join("dunst"),
            "dunst",
            ErrorCode::DunstFailed,
        )
        .inspect_err(|_| { let _ = restore_backup(&dest_config.join("dunst"), "dunst"); }),

        "rofi" => backup_and_install_dir(
            &repo_config.join("rofi"),
            &dest_config.join("rofi"),
            "rofi",
            ErrorCode::RofiFailed,
        )
        .inspect_err(|_| { let _ = restore_backup(&dest_config.join("rofi"), "rofi"); }),

        "utils" => install_utils(&repo_config, &dest_config),

        _ => Err(InstallError::new(
            ErrorCode::Unknown,
            format!("Unknown install item: {item}"),
            "This is a bug. Please open an issue and mention error code 2.",
        )),
    }
}

fn install_gtk(repo_config: &std::path::Path, home: &std::path::Path) -> Result<(), InstallError> {
    let gtk_repo = repo_config.join("gtk-theme");
    let themes_dir = home.join(".themes");

    fs::create_dir_all(&themes_dir).map_err(|e| InstallError::new(
        ErrorCode::GtkFailed,
        format!("Could not create {}: {}", themes_dir.display(), e),
        "Check write permissions on your home directory.",
    ))?;

    for theme in &["green-dark", "green-light"] {
        let tarball = gtk_repo.join(format!("{theme}.tar.gz"));
        if !tarball.exists() {
            return Err(InstallError::new(
                ErrorCode::GtkFailed,
                format!("Tarball missing: {}", tarball.display()),
                "Check that the repository contains the gtk-theme tarballs.",
            ));
        }

        let target = themes_dir.join(theme);
        if target.exists() {
            let _ = fs::remove_dir_all(&target);
        }
        fs::create_dir_all(&target).map_err(|e| InstallError::new(
            ErrorCode::GtkFailed,
            format!("Could not create {}: {}", target.display(), e),
            "Check write permissions on ~/.themes.",
        ))?;

        let file = File::open(&tarball).map_err(|e| InstallError::new(
            ErrorCode::GtkFailed,
            format!("Failed to open {}: {}", tarball.display(), e),
            "Ensure the file exists and is readable.",
        ))?;

        Archive::new(GzDecoder::new(file))
            .unpack(&target)
            .map_err(|e| InstallError::new(
                ErrorCode::GtkFailed,
                format!("Failed to extract {theme}: {e}"),
                "Ensure the tarball is not corrupted.",
            ))?;
    }
    Ok(())
}

fn install_utils(repo_config: &std::path::Path, dest_config: &std::path::Path) -> Result<(), InstallError> {
    let dirs = ["ags", "color-schemes", "fastfetch", "qt6ct", "waybar", "zathura", "spicetify", "mako"];
    for dir in &dirs {
        let src = repo_config.join(dir);
        if !src.exists() {
            continue;
        }
        backup_and_install_dir(&src, &dest_config.join(dir), dir, ErrorCode::UtilsFailed)
            .inspect_err(|_| { let _ = restore_backup(&dest_config.join(dir), dir); })?;
    }

    let starship_src = repo_config.join("starship.toml");
    if starship_src.exists() {
        copy_file(&starship_src, &dest_config.join("starship.toml"), ErrorCode::UtilsFailed)?;
    }
    Ok(())
}

#[tauri::command]
pub fn copy_quickshell(repo_root: String, selection: String) -> Result<(), InstallError> {
    let home = home_dir()?;
    let src_qs = PathBuf::from(&repo_root).join(".config/quickshell");
    let dest_qs = home.join(".config/quickshell");

    if !src_qs.exists() {
        return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            "quickshell source directory not found in repo",
            "Check that .config/quickshell/ exists in the repository.",
        ));
    }

    let dirs: &[&str] = match selection.as_str() {
        "qs-top" => &["top-bar"],
        "qs-bottom" => &["task-bar"],
        "qs-both" => &["top-bar", "task-bar"],
        _ => return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            format!("Unknown quickshell selection: {selection}"),
            "This is a bug. Please open an issue and mention error code 53.",
        )),
    };

    backup_existing(&dest_qs, "quickshell")?;

    // The .cache dir holds per-user runtime state and is not shipped; create it
    // empty so anything writing there before the weather script runs succeeds.
    let _ = fs::create_dir_all(dest_qs.join(".cache"));

    for dir in dirs {
        let src = src_qs.join(dir);
        if !src.exists() {
            let _ = restore_backup(&dest_qs, "quickshell");
            return Err(InstallError::new(
                ErrorCode::QuickshellFailed,
                format!("Required quickshell subdirectory missing: {dir}"),
                "The repository may be incomplete.",
            ));
        }
        if let Err(e) = copy_dir_contents(&src, &dest_qs.join(dir), ErrorCode::QuickshellFailed) {
            let _ = restore_backup(&dest_qs, "quickshell");
            return Err(e);
        }
    }

    let qs_config = match selection.as_str() {
        "qs-top" => "top-bar",
        _ => "task-bar",
    };
    let _ = Command::new("qs").args(["-c", qs_config]).spawn();

    Ok(())
}

#[tauri::command]
pub fn install_sddm(repo_root: String, choice: String, faceunlock: bool) -> Result<(), InstallError> {
    sddm::install(&repo_root, &choice, faceunlock)
}
