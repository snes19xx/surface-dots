use crate::thumbs::ensure_thumb;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixListener;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread;
use walkdir::WalkDir;

pub fn serve(wallpaper_dir: PathBuf, cache_dir: PathBuf, socket_path: &Path) {
    if socket_path.exists() {
        std::fs::remove_file(socket_path).expect("Failed to remove stale socket");
    }

    let listener = UnixListener::bind(socket_path).expect("Failed to bind to socket");

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let w_dir = wallpaper_dir.clone();
                let c_dir = cache_dir.clone();

                let mut write_stream = stream.try_clone().unwrap();
                let read_stream = stream;

                // thread 1: read 'apply' requests coming from qml
                thread::spawn(move || {
                    let reader = BufReader::new(read_stream);
                    for line in reader.lines() {
                        if let Ok(req) = line {
                            let req = req.trim();
                            if req.starts_with("apply:") {
                                // qml hands over the full path directly
                                let full_path = req.trim_start_matches("apply:");
                                let _ = Command::new("awww")
                                    .args([
                                        "img", full_path,
                                        "--transition-type", "wipe",
                                        "--transition-pos", "center",
                                        "--transition-step", "90",
                                        "--transition-duration", "1.2",
                                    ])
                                    .spawn();
                            }
                        }
                    }
                });

                // thread 2: build thumbs and stream them back to qml as they're ready
                thread::spawn(move || {
                    let mut items = Vec::new();
                    
                    // quick pass to collect the image files
                    for entry in WalkDir::new(&w_dir).into_iter().filter_map(|e| e.ok()) {
                        let path = entry.path();
                        if path.is_file() {
                            let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("").to_lowercase();
                            if ["png", "jpg", "jpeg", "webp"].contains(&ext.as_str()) {
                                items.push(path.to_path_buf());
                            }
                        }
                    }
                    
                    // sort so the grid order stays consistent
                    items.sort();

                    // make each thumb and fire it off as one json line
                    for path in items {
                        if let Some(thumb) = ensure_thumb(&path, &c_dir) {
                            let json = serde_json::to_string(&thumb).unwrap();
                            if write_stream.write_all(format!("{}\n", json).as_bytes()).is_err() {
                                break; // window's gone, stop
                            }
                        }
                    }
                });
            }
            Err(_) => continue,
        }
    }
}