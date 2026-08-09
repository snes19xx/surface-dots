use std::fs;
use std::path::PathBuf;

/// find the surface-dots repo root.Prioritizes SD_REPO_ROOT for dev/testing, then
/// falls back to walking up from the binary until a dir with both .config/ and
/// sddm/ is found. 
pub fn find_repo_root() -> Option<PathBuf> {
    if let Ok(override_root) = std::env::var("SD_REPO_ROOT") {
        let p = PathBuf::from(override_root);
        if p.join(".config").is_dir() && p.join("sddm").is_dir() {
            return Some(p);
        }
    }

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

/// True if an executable named `bin` is found on $PATH.
pub fn has_bin(bin: &str) -> bool {
    let Ok(path) = std::env::var("PATH") else { return false };
    std::env::split_paths(&path).any(|dir| dir.join(bin).is_file())
}

/// True if any running process's comm contains `needle`. Reads /proc directly so
/// it does not depend on pgrep being installed.
pub fn is_process_running(needle: &str) -> bool {
    let Ok(entries) = fs::read_dir("/proc") else { return false };
    for entry in entries.flatten() {
        let name = entry.file_name();
        if !name.to_string_lossy().chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        if let Ok(comm) = fs::read_to_string(entry.path().join("comm")) {
            if comm.contains(needle) {
                return true;
            }
        }
    }
    false
}

/// True if a polkit authentication agent appears to be running.
pub fn polkit_agent_running() -> bool {
    is_process_running("polkit") || is_process_running("polkit-gnome") || is_process_running("polkit-kde")
}

/// True if any Nerd/symbol font is installed (fixes the '?'-glyph reports).
pub fn nerd_font_present() -> bool {
    let Ok(output) = std::process::Command::new("fc-list").output() else { return false };
    let list = String::from_utf8_lossy(&output.stdout).to_lowercase();
    list.contains("nerd") || list.contains("symbols")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn discovers_repo_when_binary_sits_at_root() {
        // Simulate the shipped layout: binary at the surface-dots repo root,
        // next to .config/ and sddm/.
        let repo = std::env::temp_dir().join(format!("sd-root-{}", std::process::id()));
        std::fs::create_dir_all(repo.join(".config")).unwrap();
        std::fs::create_dir_all(repo.join("sddm")).unwrap();

        std::env::remove_var("SD_REPO_ROOT");
        std::env::set_var("APPIMAGE", repo.join("surface-dots-installer"));

        assert_eq!(find_repo_root().as_deref(), Some(repo.as_path()));

        std::env::remove_var("APPIMAGE");
        let _ = std::fs::remove_dir_all(&repo);
    }
}
