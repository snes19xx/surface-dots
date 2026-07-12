#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod errors;
mod fs_ops;
mod hypr;
mod paths;
mod preflight;
mod sddm;

fn main() {
    // WebKit2GTK on Wayland renders a blank window or crashes on launch for many
    // users unless compositing/GPU process are disabled. Set before the webview
    // is created. The launcher script exports the same vars as a fallback.
    for (key, val) in [
        ("WEBKIT_DISABLE_COMPOSITING_MODE", "1"),
        ("WEBKIT_DISABLE_GPU_PROCESS", "1"),
        ("WEBKIT_DISABLE_DMABUF_RENDERER", "1"),
    ] {
        if std::env::var_os(key).is_none() {
            std::env::set_var(key, val);
        }
    }

    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            commands::get_repo_root,
            commands::preflight,
            commands::configure_monitors,
            commands::copy_hypr_item,
            commands::copy_config_item,
            commands::copy_quickshell,
            commands::install_sddm,
        ])
        .run(tauri::generate_context!())
        .expect("error while running surface-dots installer");
}
