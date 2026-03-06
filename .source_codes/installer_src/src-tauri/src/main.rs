#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;
mod errors;

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            commands::get_repo_root,
            commands::copy_hypr_main,
            commands::copy_config_item,
            commands::copy_quickshell,
            commands::install_sddm,
        ])
        .run(tauri::generate_context!())
        .expect("error while running surface-dots installer");
}
