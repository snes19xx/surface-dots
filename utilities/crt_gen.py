#!/usr/bin/env python311
import os
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


def bake_crt_clean(image_path):
    print(f"BAKING CRT FX: {image_path} ---")
    
    try:
        img = Image.open(image_path).convert("RGB")
    except Exception as e:
        print(f"Error: {e}")
        return

    w, h = img.size

    # RGB Shift
    print("1. Splitting RGB Channels...", end="", flush=True)
    r, g, b = img.split()
    
    # Reduced shift slightly to keep text readable
    offset = int(w * 0.003) 
    
    r_data = np.array(r)
    r_shifted = np.roll(r_data, -offset, axis=1)
    r_new = Image.fromarray(r_shifted)

    b_data = np.array(b)
    b_shifted = np.roll(b_data, offset, axis=1)
    b_new = Image.fromarray(b_shifted)

    img_rgb = Image.merge("RGB", (r_new, g, b_new))
    print(" Done.")

    # SCANLINES
    print("2. Burning Scanlines...", end="", flush=True)
    scanline_mask = Image.new("L", (w, h), 255)
    draw = ImageDraw.Draw(scanline_mask)
    
    line_spacing = 4 
    for y in range(0, h, line_spacing):
        # Lighter lines (180) so they don't conflict with my shader
        draw.line([(0, y), (w, y)], fill=180, width=1)
    
    img_scanlines = ImageChops.multiply(img_rgb, scanline_mask.convert("RGB"))
    print(" Done.")

    # BLOOM EFFECT
    print("3. Adding Phosphor Bloom Effect...", end="", flush=True)
    glow = img_rgb.filter(ImageFilter.GaussianBlur(radius=6))
    glow = ImageEnhance.Brightness(glow).enhance(0.5)
    
    # Add glow to the scanlined image
    img_final = ImageChops.add(img_scanlines, glow)
    print(" Done.")

    # SAVE
    filename, ext = os.path.splitext(image_path)
    out_name = f"{filename}_RETRO.png"
    img_final.save(out_name, quality=95)
    print(f"\n[COMPLETE]: Saved to {out_name}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python bake_crt_clean.py <image>")
    else:
        bake_crt_clean(sys.argv[1])  