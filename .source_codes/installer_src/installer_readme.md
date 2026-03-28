# surface-dots installer

The installer is a GUI app written in Rust + Tauri.

The source code is in `.source_codes/installer_src`.

<div align="center">
    <img src="installer.png" height=500 alt="screenshot" />
</div>

## How it works

The installer finds the repo root by walking up from the binary's location until it finds a directory containing both `.config/` and `sddm/` i.e. the binary has to stay inside the repo tree.

From there it copies configs into `~/.config/`, patches paths, handles backups, and runs the SDDM install under `pkexec`.

**Path patching**

My configs had `/home/snes` hardcoded everywhere. The installer replaces all occurrences with the actual user's home directory during every file copy. It reads each file as text first, if that fails (binary file), it copies raw. This runs on every file in every directory transfer.

**Backups**

Before overwriting any config directory the installer backs up whatever is already there to `<dir>/<name>.old`. If a backup already exists from a previous run it gets cleared first.

**SDDM**

The SDDM step needs root access to copy files into `/usr/share/sddm/themes/` and write `/etc/sddm.conf.d/theme.conf`. It does all of this in one `pkexec bash -c` call so the user only sees one polkit prompt. On a real machine: they approve the prompt, the theme gets installed, and the next time they log in they see the pixel theme at the greeter.

**Quickshell**

After installing the quickshell config, the installer silently spawns `qs -c <config>` to load it immediately. If `qs` isn't installed or fails, the error is discarded. If you select `both`, only `task-bar` gets launched.

## If you want to build something like this

> _If you want to add something similar for your dotfiles, do not use this exact method. It's main objective is to serve as a personal learning experience for Rust and Tauri and I am basically recycling the front end from another project, it worked out fine but I wouldn't do it this way again. I don't think it's worth writing a dotfiles installer in tauri-- maybe packaging a tauri frontend with bash scripts could work if you want nice looking installer ui but I still wouldn't recommend it._

## Testing

If you still want to try it for yourself, write a simple front end with text box and button, put it in `/src/` and use the `sandbox.sh` script. It redirects `$HOME` to a temporary directory so the installer writes there instead of your real config.

#### Testing SDDM without touching your system

The SDDM step needs to write to `/usr/share/` and `/etc/`, which the sandbox doesn't cover. To test it safely, put a fake `pkexec` in `/tmp/fake-bin/` that intercepts the call and redirects those paths to `/tmp/sandbox-root/` instead.

The installer calls pkexec like this:

```
pkexec bash -c "cp -r '/path/to/theme' /usr/share/sddm/themes/pixel && mkdir -p /etc/sddm.conf.d && ..."
```

## Notes

- **polkit agent**: the SDDM step uses `pkexec`. The user must have a polkit authentication agent running (e.g. `polkit-kde-agent`, `polkit-gnome`).
- **webkit2gtk**: Tauri on Linux requires `webkit2gtk-4.1`.

```bash
# Arch:
sudo pacman -S webkit2gtk-4.1
# Debian:
sudo apt install libwebkit2gtk-4.1-0
# Fedora:
sudo dnf install webkit2gtk4.1
```

---

## Error code reference

`src-tauri/src/errors.rs`:

All error codes are prime numbers, because I like prime numbers.

| Code | Meaning                            | Likely cause                                         |
| ---- | ---------------------------------- | ---------------------------------------------------- |
| 2    | Internal / unknown error           | Unexpected runtime condition                         |
| 3    | Repo root not found                | Binary was moved outside the SURFACE-DOTS tree       |
| 5    | Could not determine home directory | `$HOME` not set, unusual user environment            |
| 7    | Backup failed                      | No write permission on `~/.config`                   |
| 11   | Hyprland main config copy failed   | File permissions or missing source files             |
| 13   | hyprland.conf monitor patch failed | File unreadable, or the line format changed          |
| 17   | Shaders copy failed                | Missing `hypr/shaders/` in repo                      |
| 19   | Scripts copy failed                | Missing `hypr/scripts/` or `screenshots/` in repo    |
| 23   | Hyprlock / hypridle copy failed    | Missing conf files in repo                           |
| 29   | Kitty config copy failed           | Permissions or missing source                        |
| 31   | GTK theme copy failed              | Permissions or missing source                        |
| 37   | Kvantum config copy failed         | Permissions or missing source                        |
| 41   | Dunst config copy failed           | Permissions or missing source                        |
| 43   | Rofi config copy failed            | Permissions or missing source                        |
| 47   | Other utilities copy failed        | Permissions or one of ags/waybar/etc. source missing |
| 53   | Quickshell copy failed             | Missing `quickshell/` subdirectory in repo           |
| 59   | SDDM theme source not found        | `sddm/themes/pixel/` directory missing from repo     |
| 61   | SDDM pkexec copy failed            | Polkit agent not running, or user cancelled prompt   |
| 67   | `/etc/sddm.conf.d` creation failed | pkexec denied, or polkit agent not running           |
| 71   | Setting SDDM default theme failed  | pkexec denied writing `/etc/sddm.conf.d/theme.conf`  |
| 73   | Invalid monitor resolution         | Expected format: `2880*1920` or `2880x1920`          |
| 79   | Invalid scale value                | Expected a decimal number like `1.33`                |
