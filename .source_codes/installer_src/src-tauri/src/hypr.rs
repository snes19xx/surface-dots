use std::fs;
use std::path::PathBuf;

use crate::errors::{ErrorCode, InstallError};
use crate::fs_ops::{backup_existing, copy_dir_contents, copy_file, home_dir, restore_backup};

#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MonitorInput {
    pub output: String,
    pub resolution: String,
    pub scale: String,
    pub refresh: Option<String>,
}

struct Validated {
    output: String,
    width: u32,
    height: u32,
    scale: String,
    refresh: u32,
}

fn validate(m: &MonitorInput, code: ErrorCode) -> Result<Validated, InstallError> {
    let res_clean = m.resolution.trim().replace('*', "x");
    let parts: Vec<&str> = res_clean.split('x').collect();
    let (Ok(width), Ok(height)) = (
        parts.first().unwrap_or(&"").trim().parse::<u32>(),
        parts.get(1).unwrap_or(&"").trim().parse::<u32>(),
    ) else {
        return Err(InstallError::new(
            code,
            format!("\"{}\" is not a valid resolution", m.resolution.trim()),
            "Enter the resolution as WIDTH*HEIGHT, e.g. 2880*1920. Run `hyprctl monitors` to check.",
        ));
    };
    if parts.len() != 2 {
        return Err(InstallError::new(
            code,
            format!("\"{}\" is not a valid resolution", m.resolution.trim()),
            "Enter the resolution as WIDTH*HEIGHT, e.g. 2880*1920.",
        ));
    }

    let scale_val = m.scale.trim().parse::<f64>().map_err(|_| InstallError::new(
        ErrorCode::InvalidScale,
        format!("\"{}\" is not a valid scale value", m.scale.trim()),
        "Enter a decimal number like 1, 1.33, 1.5, or 2.",
    ))?;
    if !(0.1..=8.0).contains(&scale_val) {
        return Err(InstallError::new(
            ErrorCode::InvalidScale,
            format!("Scale {scale_val} is out of range"),
            "Enter a scale between 0.1 and 8, e.g. 1, 1.33, 2.",
        ));
    }

    let refresh = match &m.refresh {
        Some(r) if !r.trim().is_empty() => r.trim().parse::<u32>().map_err(|_| InstallError::new(
            code,
            format!("\"{}\" is not a valid refresh rate", r.trim()),
            "Enter a whole number like 60, 90, or 120.",
        ))?,
        _ => 60,
    };

    let output = m.output.trim();
    Ok(Validated {
        output: if output.is_empty() { "eDP-1".to_string() } else { output.to_string() },
        width,
        height,
        scale: m.scale.trim().to_string(),
        refresh,
    })
}

fn monitor_block(v: &Validated, position: &str) -> String {
    format!(
        "hl.monitor({{\n    output   = \"{}\",\n    mode     = \"{}x{}@{}\",\n    position = \"{}\",\n    scale    = {},\n    bitdepth = 10\n}})",
        v.output, v.width, v.height, v.refresh, position, v.scale
    )
}

/// byte ranges of every `hl.monitor( ... )` call, found by tracking paren depth.
fn monitor_spans(src: &str) -> Vec<(usize, usize)> {
    let needle = "hl.monitor(";
    let bytes = src.as_bytes();
    let mut spans = Vec::new();
    let mut search = 0;
    while let Some(rel) = src[search..].find(needle) {
        let start = search + rel;
        let mut i = start + needle.len() - 1;
        let mut depth = 0i32;
        let mut end = None;
        while i < bytes.len() {
            match bytes[i] {
                b'(' => depth += 1,
                b')' => {
                    depth -= 1;
                    if depth == 0 {
                        end = Some(i + 1);
                        break;
                    }
                }
                _ => {}
            }
            i += 1;
        }
        match end {
            Some(e) => {
                spans.push((start, e));
                search = e;
            }
            None => break,
        }
    }
    spans
}

/// swap every hl.monitor() call for freshly generated ones. i leave SR4.icm out on
/// purpose, it's calibrated to my exact panel so it's useless on anyone else's.
fn rewrite_monitors(raw: &str, generated: &str) -> Result<String, InstallError> {
    let spans = monitor_spans(raw);
    if spans.is_empty() {
        return Err(InstallError::new(
            ErrorCode::MonitorGenFailed,
            "No hl.monitor(...) block found in hyprland.lua",
            "The repo's hyprland.lua may have changed format. You can set your monitor manually after install.",
        ));
    }

    let mut result = String::new();
    result.push_str(&raw[..spans[0].0]);
    result.push_str(generated);
    let mut cursor = spans[0].1;
    for &(st, en) in &spans[1..] {
        result.push_str(&raw[cursor..st]);
        cursor = en;
    }
    result.push_str(&raw[cursor..]);
    Ok(result)
}

/// first step of the hypr install: back up ~/.config/hypr, write hyprland.lua with your
/// monitor(s), then copy shader.lua and the lockscreen wallpaper.
pub fn configure_monitors(
    repo_root: &str,
    primary: MonitorInput,
    secondary: Option<MonitorInput>,
) -> Result<(), InstallError> {
    let p = validate(&primary, ErrorCode::InvalidResolution)?;
    let s = match secondary {
        Some(m) => Some(validate(&m, ErrorCode::InvalidSecondary)?),
        None => None,
    };

    let home = home_dir()?;
    let repo_hypr = PathBuf::from(repo_root).join(".config/hypr");
    let dest_hypr = home.join(".config/hypr");

    let lua_src = repo_hypr.join("hyprland.lua");
    let raw = fs::read_to_string(&lua_src).map_err(|e| InstallError::new(
        ErrorCode::HyprLuaUnreadable,
        format!("Could not read hyprland.lua from repo: {e}"),
        "Check that .config/hypr/hyprland.lua exists in the repository.",
    ))?;

    let mut generated = monitor_block(&p, "0x0");
    if let Some(sec) = &s {
        let position = format!("{}x0", p.width);
        generated.push('\n');
        generated.push_str(&monitor_block(sec, &position));
    }

    let rewritten = rewrite_monitors(&raw, &generated)?;
    let patched = rewritten.replace("/home/snes", &home.to_string_lossy());

    backup_existing(&dest_hypr, "hypr")?;
    fs::create_dir_all(&dest_hypr).map_err(|e| InstallError::new(
        ErrorCode::HyprMainFailed,
        format!("Could not create ~/.config/hypr: {e}"),
        "Check write permissions on ~/.config.",
    ))?;

    fs::write(dest_hypr.join("hyprland.lua"), patched).map_err(|e| InstallError::new(
        ErrorCode::HyprMainFailed,
        format!("Could not write hyprland.lua: {e}"),
        "Check write permissions on ~/.config/hypr.",
    ))?;

    copy_file(&repo_hypr.join("shader.lua"), &dest_hypr.join("shader.lua"), ErrorCode::ShaderCopyFailed)?;

    for file in &["background.jpg", "face.jpg"] {
        let src = repo_hypr.join(file);
        if src.exists() {
            copy_file(&src, &dest_hypr.join(file), ErrorCode::HyprMainFailed)?;
        }
    }

    Ok(())
}

/// copy one hypr sub-item into ~/.config/hypr (already backed up by the time this runs).
pub fn copy_hypr_item(repo_root: &str, item: &str) -> Result<(), InstallError> {
    let home = home_dir()?;
    let repo_hypr = PathBuf::from(repo_root).join(".config/hypr");
    let dest_hypr = home.join(".config/hypr");

    match item {
        "shaders" => copy_dir_contents(
            &repo_hypr.join("shaders"),
            &dest_hypr.join("shaders"),
            ErrorCode::HyprShadersFailed,
        ),
        "scripts" => {
            for sub in &["scripts", "screenshots"] {
                copy_dir_contents(
                    &repo_hypr.join(sub),
                    &dest_hypr.join(sub),
                    ErrorCode::HyprScriptsFailed,
                )?;
            }
            Ok(())
        }
        "lock" => {
            copy_file(
                &repo_hypr.join("hypridle.conf"),
                &dest_hypr.join("hypridle.conf"),
                ErrorCode::HyprLockFailed,
            )?;
            copy_dir_contents(
                &repo_hypr.join("hyprlock"),
                &dest_hypr.join("hyprlock"),
                ErrorCode::HyprLockFailed,
            )?;
            Ok(())
        }
        _ => Err(InstallError::new(
            ErrorCode::Unknown,
            format!("Unknown hypr item: {item}"),
            "This is a bug. Please open an issue and mention error code 2.",
        )),
    }
}

/// roll ~/.config/hypr back from its backup if a hypr step fails.
pub fn rollback_hypr() -> Result<(), InstallError> {
    let home = home_dir()?;
    restore_backup(&home.join(".config/hypr"), "hypr")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn input(output: &str, res: &str, scale: &str) -> MonitorInput {
        MonitorInput { output: output.into(), resolution: res.into(), scale: scale.into(), refresh: None }
    }

    const SAMPLE: &str = "local home = os.getenv(\"HOME\")\n\
hl.monitor({\n    output = \"eDP-1\",\n    mode = \"2256x1504@60\",\n    scale = 1,\n    icc = home .. \"/.config/hypr/SR4.icm\"\n})\n\
hl.monitor({\n    output = \"DP-2\",\n    mode = \"3840x2160@60\",\n    scale = 2\n})\n\
hl.env(\"TERMINAL\", \"kitty\")\n";

    #[test]
    fn finds_both_monitor_calls() {
        assert_eq!(monitor_spans(SAMPLE).len(), 2);
    }

    #[test]
    fn single_monitor_replaces_all_and_drops_icc() {
        let gen = monitor_block(&validate(&input("eDP-1", "2880*1920", "1.333"), ErrorCode::InvalidResolution).unwrap(), "0x0");
        let out = rewrite_monitors(SAMPLE, &gen).unwrap();
        assert_eq!(monitor_spans(&out).len(), 1);
        assert!(out.contains("2880x1920@60"));
        assert!(out.contains("scale    = 1.333"));
        assert!(!out.contains("SR4.icm"));
        assert!(!out.contains("3840x2160"));
        assert!(out.contains("hl.env(\"TERMINAL\""));
    }

    #[test]
    fn dual_monitor_positions_secondary_right() {
        let p = validate(&input("eDP-1", "2880*1920", "1"), ErrorCode::InvalidResolution).unwrap();
        let s = validate(&input("DP-2", "3840*2160", "2"), ErrorCode::InvalidSecondary).unwrap();
        let mut gen = monitor_block(&p, "0x0");
        gen.push('\n');
        gen.push_str(&monitor_block(&s, &format!("{}x0", p.width)));
        let out = rewrite_monitors(SAMPLE, &gen).unwrap();
        assert_eq!(monitor_spans(&out).len(), 2);
        assert!(out.contains("position = \"2880x0\""));
    }

    #[test]
    fn end_to_end_hypr_install_into_temp_home() {
        let repo = "/home/snes/Documents/surface-dots";
        if !std::path::Path::new(repo).join(".config/hypr/hyprland.lua").exists() {
            return; // no repo in this environment, skip
        }
        let tmp = std::env::temp_dir().join(format!("sd-e2e-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&tmp);
        std::fs::create_dir_all(&tmp).unwrap();
        std::env::set_var("HOME", &tmp);

        configure_monitors(
            repo,
            input("eDP-1", "2880*1920", "1.333"),
            Some(input("HDMI-A-1", "1920*1080", "1")),
        )
        .unwrap();

        let lua = std::fs::read_to_string(tmp.join(".config/hypr/hyprland.lua")).unwrap();
        assert!(lua.contains("2880x1920@60"));
        assert!(lua.contains("position = \"2880x0\""));
        assert!(!lua.contains("SR4.icm"));
        assert!(!lua.contains("/home/snes"));
        assert!(tmp.join(".config/hypr/shader.lua").exists());

        let _ = std::fs::remove_dir_all(&tmp);
    }

    #[test]
    fn rejects_bad_resolution_and_scale() {
        assert!(validate(&input("eDP-1", "abc", "1"), ErrorCode::InvalidResolution).is_err());
        assert!(validate(&input("eDP-1", "2880*1920", "big"), ErrorCode::InvalidResolution).is_err());
        assert!(validate(&input("eDP-1", "2880*1920", "99"), ErrorCode::InvalidResolution).is_err());
    }
}
