mod socket;
mod thumbs;

use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    let uid = Command::new("id")
        .arg("-u")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_else(|_| "1000".to_string());

    let socket_path = PathBuf::from(format!("/run/user/{}/papel.sock", uid));

    let home = env::var("HOME").expect("HOME environment variable not set");
    let cache_dir = PathBuf::from(&home).join(".cache/papel");
    fs::create_dir_all(&cache_dir).expect("Failed to create cache directory");

    let wallpaper_dir_str = env::var("PAPEL_DIR").unwrap_or_else(|_| {
        PathBuf::from(&home).join("Pictures/Wallpapers").to_string_lossy().to_string()
    });
    let wallpaper_dir = PathBuf::from(wallpaper_dir_str);
    fs::create_dir_all(&wallpaper_dir).expect("Failed to create wallpaper directory");

    // binds the socket and handles clients on their own threads
    socket::serve(wallpaper_dir, cache_dir, &socket_path);
}