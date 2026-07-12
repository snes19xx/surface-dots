use std::path::PathBuf;
use std::process::Command;

use crate::errors::{ErrorCode, InstallError};
use crate::paths::polkit_agent_running;

/// install one sddm theme and set it as default, all behind a single pkexec prompt.
/// choice is "none" | "stellarium" | "pixel". faceunlock only for pixel.
pub fn install(repo_root: &str, choice: &str, faceunlock: bool) -> Result<(), InstallError> {
    let (theme_name, src) = match choice {
        "none" => return Ok(()),
        "stellarium" => (
            "stellarium",
            PathBuf::from(repo_root).join("sddm/themes/stellarium"),
        ),
        "pixel" => {
            let variant = if faceunlock { "faceunlock_animation" } else { "no_faceanimation" };
            (
                "pixel",
                PathBuf::from(repo_root).join("sddm/themes/pixel").join(variant),
            )
        }
        _ => {
            return Err(InstallError::new(
                ErrorCode::Unknown,
                format!("Unknown SDDM choice: {choice}"),
                "This is a bug. Please open an issue and mention error code 2.",
            ))
        }
    };

    if !src.exists() {
        return Err(InstallError::new(
            ErrorCode::SddmSourceNotFound,
            format!("SDDM theme source not found: {}", src.display()),
            "Check that the sddm/themes/ directory exists in the repository.",
        ));
    }

    let skip_polkit_check = std::env::var_os("SD_SKIP_POLKIT_CHECK").is_some();
    if !skip_polkit_check && !polkit_agent_running() {
        return Err(InstallError::new(
            ErrorCode::NoPolkitAgent,
            "No polkit authentication agent is running",
            "Start one first, e.g. `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &`, then retry this step.",
        ));
    }

    // idempotent on purpose, so re-running after you cancel the prompt can't leave a half state.
    let script = format!(
        "set -e; \
         mkdir -p /usr/share/sddm/themes; \
         rm -rf '/usr/share/sddm/themes/{theme}'; \
         cp -r '{src}' '/usr/share/sddm/themes/{theme}'; \
         mkdir -p /etc/sddm.conf.d; \
         printf '[Theme]\\nCurrent={theme}\\n' > /etc/sddm.conf.d/theme.conf",
        theme = theme_name,
        src = src.display(),
    );

    let output = Command::new("pkexec")
        .arg("bash")
        .arg("-c")
        .arg(&script)
        .output()
        .map_err(|e| InstallError::new(
            ErrorCode::SddmCopyFailed,
            format!("Failed to launch pkexec: {e}"),
            "Make sure pkexec is installed. On Arch: sudo pacman -S polkit",
        ))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let hint = if output.status.code() == Some(126) {
            "You cancelled the authentication prompt. Re-run the SDDM step and approve the polkit request."
        } else {
            "Make sure a polkit authentication agent is running. If it persists, install the theme manually."
        };
        return Err(InstallError::new(
            ErrorCode::SddmCopyFailed,
            format!("SDDM installation failed: {}", stderr.trim()),
            hint,
        ));
    }

    Ok(())
}
