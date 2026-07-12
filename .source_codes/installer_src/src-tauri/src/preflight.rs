use std::path::Path;

use crate::paths;

#[derive(Debug, serde::Serialize)]
pub struct PreflightReport {
    pub blocking: Vec<String>,
    pub warnings: Vec<String>,
}

/// every repo path a full install needs. if one's missing i block the install up front
/// instead of letting it blow up three steps in.
const REQUIRED_PATHS: &[&str] = &[
    ".config/hypr/hyprland.lua",
    ".config/hypr/shader.lua",
    ".config/hypr/shaders",
    ".config/hypr/scripts",
    ".config/hypr/screenshots",
    ".config/hypr/hyprlock.conf",
    ".config/hypr/hypridle.conf",
    ".config/kitty",
    ".config/gtk-theme/green-dark.tar.gz",
    ".config/gtk-theme/green-light.tar.gz",
    ".config/kvantum",
    ".config/dunst",
    ".config/rofi",
    ".config/quickshell",
    "sddm/themes",
];

/// binaries the desktop calls at runtime. missing ones just mean broken features, they
/// don't stop the install.
const OPTIONAL_BINS: &[(&str, &str)] = &[
    ("hyprctl", "Hyprland"),
    ("qs", "Quickshell (the bars/hub)"),
    ("pkexec", "the SDDM install step"),
    ("awww", "wallpapers"),
    ("rofi", "the app launcher and menus"),
    ("kitty", "the terminal"),
    ("dunst", "notifications"),
    ("nmcli", "the network module"),
    ("pactl", "audio controls"),
    ("playerctl", "media controls"),
    ("brightnessctl", "brightness controls"),
    ("grim", "screenshots"),
    ("grimblast", "screenshots"),
    ("jq", "several helper scripts"),
    ("gsettings", "GTK theme switching"),
    ("checkupdates", "the update counter"),
];

pub fn run(repo_root: &str) -> PreflightReport {
    let root = Path::new(repo_root);
    let mut blocking = Vec::new();
    let mut warnings = Vec::new();

    for rel in REQUIRED_PATHS {
        if !root.join(rel).exists() {
            blocking.push(format!("Missing in repo: {rel}"));
        }
    }

    for (bin, feature) in OPTIONAL_BINS {
        if !paths::has_bin(bin) {
            warnings.push(format!("`{bin}` not found — {feature} will not work until installed."));
        }
    }

    if !paths::nerd_font_present() {
        warnings.push(
            "No Nerd/symbol font found — bar icons will show as '?'. Install ttf-nerd-fonts-symbols and a Nerd font."
                .to_string(),
        );
    }

    if !paths::polkit_agent_running() {
        warnings.push(
            "No polkit authentication agent detected — the SDDM step needs one running (e.g. polkit-gnome)."
                .to_string(),
        );
    }

    PreflightReport { blocking, warnings }
}
