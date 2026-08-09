use std::path::Path;

use crate::paths;

#[derive(Debug, serde::Serialize)]
pub struct PreflightReport {
    pub blocking: Vec<String>,
    pub warnings: Vec<String>,
}

/// Every repo path a full install reads. Missing entries block the install so the
/// user learns up front instead of three steps in.
const REQUIRED_PATHS: &[&str] = &[
    ".config/hypr/hyprland.lua",
    ".config/hypr/shader.lua",
    ".config/hypr/shaders",
    ".config/hypr/scripts",
    ".config/hypr/screenshots",
    ".config/hypr/hyprlock/stellarium/hyprlock.conf",
    ".config/hypr/hyprlock/pixel/hyprlock.conf",
    ".config/hypr/hypridle.conf",
    ".config/kitty",
    ".config/gtk-theme/green-dark.tar.gz",
    ".config/gtk-theme/green-light.tar.gz",
    ".config/kvantum",
    ".config/hypr/wallpapers",
    "cursor",
    ".config/dunst",
    ".config/rofi",
    ".config/quickshell",
    "sddm/themes",
];

/// Binaries the desktop calls; absence degrades features but never blocks copying.
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
    ("hyprpicker", "the colour picker on Super + P"),
    ("upower", "battery health readings"),
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
            warnings.push(format!("`{bin}` not found. {feature} will not work until installed."));
        }
    }

    if !paths::nerd_font_present() {
        warnings.push(
            "No Nerd/symbol font found. Bar icons will show as '?'. Install ttf-nerd-fonts-symbols and a Nerd font."
                .to_string(),
        );
    }

    if !paths::polkit_agent_running() {
        warnings.push(
            "No polkit authentication agent detected. The SDDM step needs one running (hyprpolkitagent or polkit-gnome)."
                .to_string(),
        );
    }

    PreflightReport { blocking, warnings }
}
