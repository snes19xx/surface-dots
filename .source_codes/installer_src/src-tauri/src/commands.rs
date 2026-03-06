use std::fs::{self, File};
use std::path::{Path, PathBuf};
use std::process::Command;

use flate2::read::GzDecoder;
use tar::Archive;

use crate::errors::{ErrorCode, InstallError};

// --- Finding the repo root ---

// Walk up from the binary's location until it finds a folder that has
// both a .config/ and a sddm/ directory - that's the repo root. Stop after 10 levels that's more than enough
fn find_repo_root() -> Option<PathBuf> {
    // Originally I wanted to package the installer as an app image to make it
    // cross distro compatible but I found it a nightmare to setup right
    // this check is just a vestigial code from that:
    let start_path = if let Ok(appimage_var) = std::env::var("APPIMAGE") {
        PathBuf::from(appimage_var)
    } else {
        std::env::current_exe().ok()?
    };

    let mut current = start_path.parent()?.to_path_buf();

    for _ in 0..10 {
        if current.join(".config").is_dir() && current.join("sddm").is_dir() {
            return Some(current);
        }
        match current.parent() {
            Some(p) => current = p.to_path_buf(),
            None => break,
        }
    }
    None
}

// Just reads $HOME and turns it into a PathBuf. Errors if $HOME isn't set.
fn home_dir() -> Result<PathBuf, InstallError> {
    std::env::var("HOME")
        .map(PathBuf::from)
        .map_err(|_| InstallError::new(
            ErrorCode::HomeNotFound,
            "Could not determine the home directory",
            "Make sure $HOME is set in your environment.",
        ))
}

// --- File system helpers ---

// Copies everything inside src into dest, recursively.
// Skips any folder or file ending in .old so it dosn't re-backup old backups.
fn copy_dir_contents(src: &Path, dest: &Path, error_code: ErrorCode) -> Result<(), InstallError> {
    fs::create_dir_all(dest).map_err(|e| InstallError::new(
        error_code,
        format!("Could not create destination directory {}: {}", dest.display(), e),
        "Check write permissions on ~/.config",
    ))?;

    let entries = fs::read_dir(src).map_err(|e| InstallError::new(
        error_code,
        format!("Could not read source directory {}: {}", src.display(), e),
        "Check that the repository structure is intact.",
    ))?;

    for entry in entries {
        let entry = entry.map_err(|e| InstallError::new(error_code, e.to_string(), ""))?;
        let path = entry.path();
        let name = path.file_name().unwrap().to_string_lossy();

        // Skip .old directories
        if name.ends_with(".old") {
            continue;
        }

        let dest_path = dest.join(path.file_name().unwrap());

        if path.is_dir() {
            copy_dir_contents(&path, &dest_path, error_code)?;
        } else {
            // Route through copy_file
            copy_file(&path, &dest_path, error_code)?;
        }
    }
    Ok(())
}

// If the target directory already exists, back it up to <dir>/<name>.old/
// before overwriting it.
fn backup_existing(dir: &Path, name: &str) -> Result<(), InstallError> {
    if !dir.exists() {
        return Ok(());
    }

    let backup = dir.join(format!("{}.old", name));

    // Wipe the old backup here
    if backup.exists() {
        fs::remove_dir_all(&backup).map_err(|e| InstallError::new(
            ErrorCode::BackupFailed,
            format!("Could not remove old backup at {}: {}", backup.display(), e),
            "Check permissions on your ~/.config directory.",
        ))?;
    }

    fs::create_dir_all(&backup).map_err(|e| InstallError::new(
        ErrorCode::BackupFailed,
        format!("Could not create backup directory: {}", e),
        "Check write permissions on ~/.config.",
    ))?;

    copy_dir_contents(dir, &backup, ErrorCode::BackupFailed)?;
    Ok(())
}

// back up dest, then copy src into dest.
fn backup_and_install_dir(src: &Path, dest: &Path, name: &str, error_code: ErrorCode) -> Result<(), InstallError> {
    backup_existing(dest, name)?;
    copy_dir_contents(src, dest, error_code)?;
    Ok(())
}

// Copies a single file. If it's a text file, replaces any hardcoded /home/snes
// paths with the actual user's home directory. If it's binary, just copies it as-is.
// Preserves original file permissions in both cases.
fn copy_file(src: &Path, dest: &Path, error_code: ErrorCode) -> Result<(), InstallError> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|e| InstallError::new(
            error_code,
            format!("Could not create directory {}: {}", parent.display(), e),
            "Check write permissions.",
        ))?;
    }

    let home_path = home_dir()?;
    let home_str = home_path.to_string_lossy();

    let src_metadata = fs::metadata(src).map_err(|e| InstallError::new(
        error_code,
        format!("Failed to read metadata for {}: {}", src.display(), e),
        "Check that the file exists in the repo.",
    ))?;

    // Try reading as text first. If that fails just copy it raw.
    match fs::read_to_string(src) {
        Ok(content) => {
            let patched = content.replace("/home/snes", &home_str);
            fs::write(dest, patched).map_err(|e| InstallError::new(
                error_code,
                format!("Failed to write patched file {} → {}: {}", src.display(), dest.display(), e),
                "Check that you have write access to ~/.config.",
            ))?;
            
            fs::set_permissions(dest, src_metadata.permissions()).map_err(|e| InstallError::new(
                error_code,
                format!("Failed to apply original permissions to {}: {}", dest.display(), e),
                "Check your filesystem permissions.",
            ))?;
        }
        Err(_) => {
            fs::copy(src, dest).map_err(|e| InstallError::new(
                error_code,
                format!("Failed to copy binary file {} → {}: {}", src.display(), dest.display(), e),
                "Check that the file exists in the repo and that you have write access to ~/.config.",
            ))?;
        }
    }
    Ok(())
}

// --- Tauri commands ---

#[tauri::command]
pub fn get_repo_root() -> Result<String, InstallError> {
    find_repo_root()
        .map(|p| p.to_string_lossy().into_owned())
        .ok_or_else(|| InstallError::new(
            ErrorCode::RepoNotFound,
            "Could not locate the SURFACE-DOTS repository",
            "Make sure you are running the installer from within the SURFACE-DOTS repository. \
             If you moved the binary, place it back inside the repo tree and try again.",
        ))
}

// Step 1 of the hypr install:
//   - backs up the user's existing ~/.config/hypr/
//   - copies hyprland.conf with the monitor line rewritten to their resolution and scale
//   - copies background.jpg and face.jpg
//
// Resolution should be "WIDTHxHEIGHT" or "WIDTH*HEIGHT".
// Scale should be a decimal string like "1.33".
#[tauri::command]
pub fn copy_hypr_main(repo_root: String, resolution: String, scale: String) -> Result<(), InstallError> {
    // Validate inputs before touching any files.
    let res_clean = resolution.trim().replace('*', "x");
    let parts: Vec<&str> = res_clean.split('x').collect();
    if parts.len() != 2
        || parts[0].parse::<u32>().is_err()
        || parts[1].parse::<u32>().is_err()
    {
        return Err(InstallError::new(
            ErrorCode::InvalidResolution,
            format!("\"{}\" is not a valid resolution", resolution.trim()),
            "Enter the resolution as WIDTH*HEIGHT, for example 2880*1920. \
             Run `hyprctl monitors` in a terminal to see your monitor's resolution.",
        ));
    }

    scale.trim().parse::<f64>().map_err(|_| InstallError::new(
        ErrorCode::InvalidScale,
        format!("\"{}\" is not a valid scale value", scale.trim()),
        "Enter a decimal number like 1, 1.33, 1.5, or 2.",
    ))?;

    // Set up source and destination paths.
    let home = home_dir()?;
    let repo = PathBuf::from(&repo_root);
    let repo_hypr = repo.join(".config").join("hypr");
    let dest_hypr = home.join(".config").join("hypr");

    // Back up whatever is already in ~/.config/hypr.
    backup_existing(&dest_hypr, "hypr").map_err(|mut e| {
        e.hint = format!(
            "Backup of ~/.config/hypr failed. {}",
            e.hint
        );
        e
    })?;

    fs::create_dir_all(&dest_hypr).map_err(|e| InstallError::new(
        ErrorCode::HyprMainFailed,
        format!("Could not create ~/.config/hypr: {}", e),
        "Check write permissions on ~/.config.",
    ))?;

    // Read hyprland.conf, patch the monitor line, then also replace /home/snes with the real home.
    let hyprland_conf_src = repo_hypr.join("hyprland.conf");
    let raw = fs::read_to_string(&hyprland_conf_src).map_err(|e| InstallError::new(
        ErrorCode::HyprMainFailed,
        format!("Could not read hyprland.conf from repo: {}", e),
        "Check that the repository is complete and hypr/hyprland.conf exists.",
    ))?;

    let patched = patch_monitor_line(&raw, &res_clean, scale.trim())
        .ok_or_else(|| InstallError::new(
            ErrorCode::HyprPatchFailed,
            "Could not find the monitor line to patch in hyprland.conf",
            "The expected line starting with `monitor = eDP-1,` was not found on line 28. \
             The repo may have been modified. You can patch it manually after install.",
        ))?;

    let home_str = home.to_string_lossy();
    let final_content = patched.replace("/home/snes", &home_str);

    fs::write(dest_hypr.join("hyprland.conf"), final_content).map_err(|e| InstallError::new(
        ErrorCode::HyprMainFailed,
        format!("Could not write hyprland.conf: {}", e),
        "Check write permissions on ~/.config/hypr.",
    ))?;

    // Copy the wallpaper and face image.
    for file in &["background.jpg", "face.jpg"] {
        copy_file(&repo_hypr.join(file), &dest_hypr.join(file), ErrorCode::HyprMainFailed)?;
    }

    Ok(())
}

// Rewrites the `monitor = eDP-1, ...` line in hyprland.conf.
// Returns None if can't be found.
fn patch_monitor_line(content: &str, resolution_x: &str, scale: &str) -> Option<String> {
    let new_line = format!(
        "monitor = eDP-1, {}@60, 0x0, {}, bitdepth, 10, cm, srgb",
        resolution_x, scale
    );

    // Line 28 
    let mut lines: Vec<&str> = content.lines().collect();
    if lines.get(27).map(|l| l.trim_start().starts_with("monitor = eDP-1,")) == Some(true) {
        lines[27] = Box::leak(new_line.into_boxed_str());
        return Some(lines.join("\n"));
    }

    // If it's not on line 28, scan the whole file.
    let mut found = false;
    let result = content
        .lines()
        .map(|line| {
            if !found && line.trim_start().starts_with("monitor = eDP-1,") {
                found = true;
                new_line.as_str()
            } else {
                line
            }
        })
        .collect::<Vec<_>>()
        .join("\n");

    if found { Some(result) } else { None }
}

// Installs a single config item by name.
// Handles hypr sub-configs (shaders, scripts, lock) and all the utility configs
// (kitty, gtk, kvantum, dunst, rofi, and the misc utils bundle).
#[tauri::command]
pub fn copy_config_item(repo_root: String, item: String) -> Result<(), InstallError> {
    let home = home_dir()?;
    let repo = PathBuf::from(&repo_root);
    let repo_config = repo.join(".config");
    let dest_config = home.join(".config");

    match item.as_str() {
        // Hypr sub-items - no extra backup needed here since copy_hypr_main already did it.

        "hypr-shaders" => {
            let src = repo_config.join("hypr").join("shaders");
            let dest = dest_config.join("hypr").join("shaders");
            copy_dir_contents(&src, &dest, ErrorCode::HyprShadersFailed)
        }

        "hypr-scripts" => {
            let hypr_dest = dest_config.join("hypr");
            for sub in &["scripts", "screenshots"] {
                let src = repo_config.join("hypr").join(sub);
                let dest = hypr_dest.join(sub);
                copy_dir_contents(&src, &dest, ErrorCode::HyprScriptsFailed)?;
            }
            Ok(())
        }

        "hypr-lock" => {
            let repo_hypr = repo_config.join("hypr");
            let dest_hypr = dest_config.join("hypr");
            for file in &["hypridle.conf", "hyprlock.conf"] {
                copy_file(&repo_hypr.join(file), &dest_hypr.join(file), ErrorCode::HyprLockFailed)?;
            }
            Ok(())
        }

        // Utility configs.

        "kitty" => {
            backup_and_install_dir(
                &repo_config.join("kitty"),
                &dest_config.join("kitty"),
                "kitty",
                ErrorCode::KittyFailed,
            )
        }

        "gtk" => {
            let gtk_repo = repo_config.join("gtk-theme");
            let themes_dir = home.join(".themes");

            fs::create_dir_all(&themes_dir).map_err(|e| InstallError::new(
                ErrorCode::GtkFailed,
                format!("Could not create directory {}: {}", themes_dir.display(), e),
                "Check write permissions on your home directory.",
            ))?;

            for theme in &["green-dark", "green-light"] {
                let tarball = gtk_repo.join(format!("{}.tar.gz", theme));
                if !tarball.exists() {
                    return Err(InstallError::new(
                        ErrorCode::GtkFailed,
                        format!("Tarball missing: {}", tarball.display()),
                        "Check that the repository structure is intact and contains gtk-theme tarballs.",
                    ));
                }

                let target_theme_dir = themes_dir.join(theme);
                if target_theme_dir.exists() {
                    let _ = fs::remove_dir_all(&target_theme_dir);
                }

                // Create the destination folder before extracting into it.
                fs::create_dir_all(&target_theme_dir).map_err(|e| InstallError::new(
                    ErrorCode::GtkFailed,
                    format!("Could not create theme directory {}: {}", target_theme_dir.display(), e),
                    "Check write permissions on ~/.themes.",
                ))?;

                let tarball_file = File::open(&tarball).map_err(|e| InstallError::new(
                    ErrorCode::GtkFailed,
                    format!("Failed to open tarball {}: {}", tarball.display(), e),
                    "Ensure the file exists and is readable.",
                ))?;

                let tar = GzDecoder::new(tarball_file);
                let mut archive = Archive::new(tar);

                archive.unpack(&target_theme_dir).map_err(|e| InstallError::new(
                    ErrorCode::GtkFailed,
                    format!("Failed to extract {}: {}", theme, e),
                    "Ensure the tarball is not corrupted.",
                ))?;
            }
            Ok(())
        }

        "kvantum" => {
            backup_and_install_dir(
                &repo_config.join("kvantum"),
                &dest_config.join("kvantum"),
                "kvantum",
                ErrorCode::KvantumFailed,
            )
        }

        "dunst" => {
            backup_and_install_dir(
                &repo_config.join("dunst"),
                &dest_config.join("dunst"),
                "dunst",
                ErrorCode::DunstFailed,
            )
        }

        "rofi" => {
            backup_and_install_dir(
                &repo_config.join("rofi"),
                &dest_config.join("rofi"),
                "rofi",
                ErrorCode::RofiFailed,
            )
        }

        "utils" => {
            // Everything else: ags, color-schemes, fastfetch, qt6ct, waybar, zathura, spicetify.
            let dirs = ["ags", "color-schemes", "fastfetch", "qt6ct", "waybar", "zathura", "spicetify"];
            for dir in &dirs {
                let src = repo_config.join(dir);
                if !src.exists() {
                    // These are optional - skip silently if missing.
                    continue;
                }
                backup_and_install_dir(&src, &dest_config.join(dir), dir, ErrorCode::UtilsFailed)?;
            }

            // starship.toml is directly in .config/ not in a subdirectory.
            let starship_src = repo_config.join("starship.toml");
            if starship_src.exists() {
                copy_file(
                    &starship_src,
                    &dest_config.join("starship.toml"),
                    ErrorCode::UtilsFailed,
                )?;
            }

            Ok(())
        }

        _ => Err(InstallError::new(
            ErrorCode::Unknown,
            format!("Unknown install item: {}", item),
            "This is a bug. Please open an issue and mention error code 2.",
        )),
    }
}

// Copies the quickshell config based on what the user picked.
// selection is one of: "qs-top", "qs-bottom", "qs-both"
#[tauri::command]
pub fn copy_quickshell(repo_root: String, selection: String) -> Result<(), InstallError> {
    let home = home_dir()?;
    let repo = PathBuf::from(&repo_root);
    let src_qs = repo.join(".config").join("quickshell");
    let dest_qs = home.join(".config").join("quickshell");

    if !src_qs.exists() {
        return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            "quickshell source directory not found in repo",
            "Check that .config/quickshell/ exists in the SURFACE-DOTS repository.",
        ));
    }

    backup_existing(&dest_qs, "quickshell")?;

    let dirs: &[&str] = match selection.as_str() {
        "qs-top"    => &[".cache", "top-bar"],
        "qs-bottom" => &[".cache", "task-bar"],
        "qs-both"   => &[".cache", "top-bar", "task-bar"],
        _ => return Err(InstallError::new(
            ErrorCode::QuickshellFailed,
            format!("Unknown quickshell selection: {}", selection),
            "This is a bug. Please open an issue and mention error code 53.",
        )),
    };

    for dir in dirs {
        let src = src_qs.join(dir);
        if !src.exists() {
            return Err(InstallError::new(
                ErrorCode::QuickshellFailed,
                format!("Required quickshell subdirectory missing: {}", dir),
                "The repository may be incomplete. Check that all quickshell subdirectories are present.",
            ));
        }
        copy_dir_contents(&src, &dest_qs.join(dir), ErrorCode::QuickshellFailed)?;
    }

    // After installing, silently launch quickshell with the right config so the
    // user sees it load immediately. if qs isn't installed or
    // fails for any reason move on without screaming an error.
    let qs_config = match selection.as_str() {
        "qs-top"    => "top-bar",
        "qs-bottom" => "task-bar",
        "qs-both"   => "task-bar",
        _           => "",
    };
    if !qs_config.is_empty() {
        let _ = Command::new("qs")
            .args(["-c", qs_config])
            .spawn();
    }

    Ok(())
}

// Installs the SDDM theme and sets it as default, all in one pkexec prompt.
#[tauri::command]
pub fn install_sddm(repo_root: String, use_faceunlock: bool) -> Result<(), InstallError> {
    let repo = PathBuf::from(&repo_root);
    let variant = if use_faceunlock { "faceunlock_animation" } else { "no_faceanimation" };
    let src = repo.join("sddm").join("themes").join("pixel").join(variant);

    if !src.exists() {
        return Err(InstallError::new(
            ErrorCode::SddmSourceNotFound,
            format!("SDDM theme source not found: {}", src.display()),
            "Check that sddm/themes/pixel/ exists in the SURFACE-DOTS repository.",
        ));
    }

    // copy and the config write 
    let script = format!(
        "mkdir -p /usr/share/sddm/themes && \
         cp -r '{src}' /usr/share/sddm/themes/pixel && \
         mkdir -p /etc/sddm.conf.d && \
         echo -e '[Theme]\\nCurrent=pixel' > /etc/sddm.conf.d/theme.conf",
        src = src.display()
    );

    let output = Command::new("pkexec")
        .arg("bash")
        .arg("-c")
        .arg(&script)
        .output()
        .map_err(|e| InstallError::new(
            ErrorCode::SddmCopyFailed,
            format!("Failed to launch pkexec: {}", e),
            "Make sure pkexec is installed. On Arch: sudo pacman -S polkit",
        ))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let hint = if output.status.code() == Some(126) {
            "You cancelled the authentication prompt. Re-run the SDDM step and approve the polkit request."
        } else {
            "Make sure a polkit authentication agent is running. If the issue persists, install manually."
        };
        return Err(InstallError::new(
            ErrorCode::SddmCopyFailed,
            format!("SDDM installation failed: {}", stderr.trim()),
            hint,
        ));
    }

    Ok(())
}