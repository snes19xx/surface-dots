use image::imageops::FilterType;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::path::{Path, PathBuf};

#[derive(Serialize)]
pub struct Thumb {
    pub id: String,
    pub thumb_path: String,
    pub full_path: String,
    pub file_name: String,
}

pub fn ensure_thumb(full_path: &Path, cache_dir: &Path) -> Option<Thumb> {
    let path_str = full_path.to_string_lossy();
    let mut hasher = Sha256::new();
    hasher.update(path_str.as_bytes());
    let id = hex::encode(hasher.finalize());

    let thumb_name = format!("{}.jpg", id);
    let thumb_path: PathBuf = cache_dir.join(&thumb_name);

    if !thumb_path.exists() {
        let img = match image::open(full_path) {
            Ok(i) => i,
            Err(_) => return None,
        };
        let thumb = img.resize_to_fill(256, 256, FilterType::Triangle);
        if thumb.save(&thumb_path).is_err() {
            return None;
        }
    }

    let file_name = full_path.file_name()?.to_string_lossy().to_string();

    Some(Thumb {
        id,
        thumb_path: thumb_path.to_string_lossy().to_string(),
        full_path: path_str.to_string(),
        file_name,
    })
}