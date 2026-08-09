use std::fs::{self, File};
use std::path::PathBuf;
use std::process::{Command, Stdio};

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
pub fn install_hyprlock(repo_root: String, theme: String) -> Result<(), InstallError> {
    let result = hypr::install_hyprlock(&repo_root, &theme);
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

        "kvantum" => install_kvantum(&repo_config, &dest_config),

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

        "utils" => install_utils(&repo_config, &dest_config, &home),

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

/// Kvantum only ever looks in ~/.config/Kvantum, capital K. Earlier versions of this
/// installer wrote the lowercase one, so move that out of the way if it's still around.
fn install_kvantum(repo_config: &std::path::Path, dest_config: &std::path::Path) -> Result<(), InstallError> {
    let dest = dest_config.join("Kvantum");

    let legacy = dest_config.join("kvantum");
    if legacy.is_dir() && !legacy.starts_with(&dest) && legacy != dest {
        let parked = dest_config.join("kvantum.pre-surface-dots");
        let _ = fs::remove_dir_all(&parked);
        let _ = fs::rename(&legacy, &parked);
    }

    backup_and_install_dir(
        &repo_config.join("kvantum"),
        &dest,
        "kvantum",
        ErrorCode::KvantumFailed,
    )
    .inspect_err(|_| { let _ = restore_backup(&dest, "kvantum"); })
}

fn install_utils(repo_config: &std::path::Path, dest_config: &std::path::Path, home: &std::path::Path) -> Result<(), InstallError> {
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

    install_cursors(repo_config, home)?;
    Ok(())
}

/// Saturnian cursors into ~/.local/share/icons.
fn install_cursors(repo_config: &std::path::Path, home: &std::path::Path) -> Result<(), InstallError> {
    let Some(repo_root) = repo_config.parent() else { return Ok(()) };
    let icons = home.join(".local/share/icons");

    for theme in &["Saturnian-Night", "Saturnian-Day"] {
        let src = repo_root.join("cursor").join(theme);
        if !src.is_dir() {
            continue;
        }
        let dest = icons.join(theme);
        let _ = fs::remove_dir_all(&dest);
        copy_dir_contents(&src, &dest, ErrorCode::UtilsFailed)?;
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

    // Both bars are in one config, so the choice only picks which one starts.
    let bar_style = match selection.as_str() {
        "top" | "task" => selection.as_str(),
        _ => return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            format!("Unknown quickshell selection: {selection}"),
            "This is a bug. Please open an issue and mention error code 53.",
        )),
    };

    backup_existing(&dest_qs, "quickshell")?;

    // Older installs kept the shell under top-bar/ and task-bar/. The copy below
    // merges, so clear those out or they sit there stale.
    for legacy in &["top-bar", "task-bar"] {
        let _ = fs::remove_dir_all(dest_qs.join(legacy));
    }

    if let Err(e) = copy_dir_contents(&src_qs, &dest_qs, ErrorCode::QuickshellFailed) {
        let _ = restore_backup(&dest_qs, "quickshell");
        return Err(e);
    }

    // The .cache dir holds per-user runtime state and is not shipped; create it
    // empty so anything writing there before the weather script runs succeeds.
    let _ = fs::create_dir_all(dest_qs.join(".cache"));

    // lib/usersettings.json is per-user state and is not shipped either. Writing
    // barStyle here applies the choice above on first launch.
    let settings = dest_qs.join("lib/usersettings.json");
    if let Err(e) = fs::write(&settings, format!("{{\"barStyle\":\"{bar_style}\"}}\n")) {
        let _ = restore_backup(&dest_qs, "quickshell");
        return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            format!("Could not write {}: {}", settings.display(), e),
            "Check write permissions on ~/.config/quickshell.",
        ));
    }

    let _ = Command::new("qs").spawn();

    Ok(())
}

#[tauri::command]
pub fn install_sddm(repo_root: String, choice: String, faceunlock: bool) -> Result<(), InstallError> {
    sddm::install(&repo_root, &choice, faceunlock)
}

/// Sets the default wallpaper and sends a greeting once everything is copied.
/// All of it is optional, so a missing binary just makes for a quieter finish.
#[tauri::command]
pub fn finish_setup() {
    let Ok(home) = home_dir() else { return };

    let wallpaper = home.join(".config/hypr/wallpapers/default-dark.jpg");
    if wallpaper.is_file() {
        // awww img needs the daemon running
        let daemon_up = Command::new("awww")
            .arg("query")
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

        if !daemon_up {
            let _ = Command::new("awww-daemon")
                .args(["--format", "xrgb"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn();
            std::thread::sleep(std::time::Duration::from_millis(1500));
        }

        let _ = Command::new("awww")
            .arg("img")
            .arg(&wallpaper)
            .args([
                "--transition-type", "wipe",
                "--transition-pos", "center",
                "--transition-step", "90",
                "--transition-duration", "1.2",
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn();
    }

    let _ = Command::new("notify-send")
        .args(["-a", "surface-dots", "Welcome to surface-dots"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn();
}
