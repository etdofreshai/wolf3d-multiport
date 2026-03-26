#!/usr/bin/env python3
"""Compare frame captures across three Wolf3D ports."""

import os
import sys
from pathlib import Path
from PIL import Image
import numpy as np

# Port capture directories
BASE = Path(__file__).parent
C_DIR = BASE / "src" / "c-sdl3-port" / "build" / "captures"
CSHARP_DIR = BASE / "captures"  # Written from multiport root
LOVE2D_DIR = Path(os.environ.get("APPDATA", "")) / "LOVE" / "wolf3d"

OUTPUT_DIR = BASE / "comparison_output"
OUTPUT_DIR.mkdir(exist_ok=True)

def load_frames(directory, ext, max_count=500):
    """Load all frames from a directory."""
    files = sorted(directory.glob(f"frame_*.{ext}"))[:max_count]
    frames = []
    for f in files:
        idx = int(f.stem.split("_")[1])
        frames.append((idx, f))
    return frames

def find_first_non_black(directory, ext, threshold=10):
    """Find the first frame that isn't all black."""
    files = sorted(directory.glob(f"frame_*.{ext}"))
    for f in files:
        img = Image.open(f).convert("RGB")
        arr = np.array(img)
        if arr.max() > threshold:
            idx = int(f.stem.split("_")[1])
            return idx, f, img
    return None, None, None

def find_peak_frame(directory, ext, max_scan=500):
    """Find the frame with the highest mean pixel value (most content)."""
    files = sorted(directory.glob(f"frame_*.{ext}"))[:max_scan]
    best_mean = 0
    best = None
    for f in files:
        img = Image.open(f).convert("RGB")
        arr = np.array(img)
        m = arr.mean()
        if m > best_mean:
            best_mean = m
            idx = int(f.stem.split("_")[1])
            best = (idx, f, img, best_mean)
    return best

def compare_images(img1, img2, tolerance=5):
    """Compare two PIL images pixel-by-pixel."""
    arr1 = np.array(img1.convert("RGB"), dtype=np.int16)
    arr2 = np.array(img2.convert("RGB"), dtype=np.int16)

    if arr1.shape != arr2.shape:
        return 0.0, f"Shape mismatch: {arr1.shape} vs {arr2.shape}", None

    diff = np.abs(arr1 - arr2)
    matches = np.all(diff <= tolerance, axis=2)
    match_pct = np.mean(matches) * 100.0

    # Create diff visualization
    diff_vis = np.zeros_like(arr1, dtype=np.uint8)
    diff_mag = np.max(diff, axis=2)
    diff_vis[:, :, 0] = np.clip(diff_mag * 10, 0, 255).astype(np.uint8)
    diff_vis[:, :, 1] = (matches * 100).astype(np.uint8)

    return match_pct, f"{match_pct:.2f}% match", Image.fromarray(diff_vis)

def find_best_match(reference_img, directory, ext, tolerance=5, max_scan=200):
    """Find the frame in directory that best matches the reference image."""
    ref_arr = np.array(reference_img.convert("RGB"), dtype=np.int16)
    files = sorted(directory.glob(f"frame_*.{ext}"))[:max_scan]

    best_pct = 0
    best_frame = None
    for f in files:
        img = Image.open(f).convert("RGB")
        arr = np.array(img, dtype=np.int16)
        if arr.shape != ref_arr.shape:
            continue
        diff = np.abs(ref_arr - arr)
        matches = np.all(diff <= tolerance, axis=2)
        pct = np.mean(matches) * 100.0
        if pct > best_pct:
            best_pct = pct
            idx = int(f.stem.split("_")[1])
            best_frame = (idx, f, img, pct)
    return best_frame

def main():
    print("=" * 70)
    print("Wolf3D Multi-Port Frame Comparison")
    print("=" * 70)
    print()

    # 1. Enumerate captures
    ports = {
        "C SDL3": (C_DIR, "bmp"),
        "C# SDL3": (CSHARP_DIR, "bmp"),
        "Love2D": (LOVE2D_DIR, "png"),
    }

    for name, (dir_path, ext) in ports.items():
        if not dir_path.exists():
            print(f"  {name}: MISSING ({dir_path})")
            continue
        count = len(list(dir_path.glob(f"frame_*.{ext}")))
        print(f"  {name}: {count} frames in {dir_path}")

    print()

    # 2. Find first non-black and peak frames
    print("--- First non-black frame ---")
    first_frames = {}
    for name, (dir_path, ext) in ports.items():
        if not dir_path.exists():
            continue
        idx, path, img = find_first_non_black(dir_path, ext)
        if img:
            print(f"  {name}: frame {idx} ({path.name})")
            first_frames[name] = (idx, img)
            img.save(OUTPUT_DIR / f"first_nonblack_{name.replace(' ', '_').replace('#', 'sharp')}.png")
        else:
            print(f"  {name}: ALL FRAMES BLACK")

    print()
    print("--- Peak content frame ---")
    peak_frames = {}
    for name, (dir_path, ext) in ports.items():
        if not dir_path.exists():
            continue
        result = find_peak_frame(dir_path, ext)
        if result and result[3] > 1.0:
            idx, path, img, mean_val = result
            print(f"  {name}: frame {idx} (mean pixel={mean_val:.1f})")
            peak_frames[name] = (idx, img)
            img.save(OUTPUT_DIR / f"peak_{name.replace(' ', '_').replace('#', 'sharp')}.png")
        else:
            print(f"  {name}: No significant content found")

    print()

    # 3. Cross-port comparison using peak frames
    print("--- Cross-port peak frame comparison (tolerance=5) ---")
    peak_names = list(peak_frames.keys())
    for i in range(len(peak_names)):
        for j in range(i+1, len(peak_names)):
            n1, n2 = peak_names[i], peak_names[j]
            idx1, img1 = peak_frames[n1]
            idx2, img2 = peak_frames[n2]
            pct, info, diff_img = compare_images(img1, img2)
            print(f"  {n1} (frame {idx1}) vs {n2} (frame {idx2}): {info}")
            if diff_img:
                s1 = n1.replace(' ', '_').replace('#', 'sharp')
                s2 = n2.replace(' ', '_').replace('#', 'sharp')
                diff_img.save(OUTPUT_DIR / f"diff_peak_{s1}_vs_{s2}.png")

    print()

    # 4. Find best frame match across ports
    print("--- Best frame match search ---")
    for name1, (dir1, ext1) in ports.items():
        if name1 not in peak_frames:
            continue
        _, ref_img = peak_frames[name1]
        for name2, (dir2, ext2) in ports.items():
            if name1 == name2 or not dir2.exists():
                continue
            result = find_best_match(ref_img, dir2, ext2, tolerance=1)
            if result:
                idx, path, img, pct = result
                print(f"  Best match for {name1}'s peak in {name2}: frame {idx} ({pct:.1f}% at tolerance=1)")
                # Also compare at tolerance=5
                _, info5, _ = compare_images(ref_img, img, tolerance=5)
                print(f"    At tolerance=5: {info5}")
                img.save(OUTPUT_DIR / f"bestmatch_{name2.replace(' ', '_').replace('#', 'sharp')}_for_{name1.replace(' ', '_').replace('#', 'sharp')}.png")
            else:
                print(f"  No match found for {name1}'s peak in {name2}")

    print()

    # 5. Frame-by-frame comparison at specific indices (for ports with matching content)
    if "C SDL3" in peak_frames and "Love2D" in peak_frames:
        print("--- Frame progression comparison: C SDL3 vs Love2D ---")
        c_frames = load_frames(C_DIR, "bmp", 200)
        love_frames = load_frames(LOVE2D_DIR, "png", 200)

        # Compare title screen region (frames where both have content)
        for c_idx, c_path in c_frames:
            if c_idx % 10 != 0:
                continue
            c_img = Image.open(c_path).convert("RGB")
            c_arr = np.array(c_img)
            if c_arr.max() < 10:
                continue

            # Find best Love2D match for this C frame
            result = find_best_match(c_img, LOVE2D_DIR, "png", tolerance=1, max_scan=200)
            if result and result[3] > 90:
                l_idx, _, _, pct = result
                print(f"  C frame {c_idx:3d} matches Love2D frame {l_idx:3d} at {pct:.1f}%")

    print()
    print(f"Output saved to: {OUTPUT_DIR}")
    print("Files:")
    for f in sorted(OUTPUT_DIR.glob("*.png")):
        print(f"  {f.name}")

if __name__ == "__main__":
    main()
