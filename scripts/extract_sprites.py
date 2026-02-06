#!/usr/bin/env python3
"""Extract sprite frames from MP4 animations with cycle detection and normalization.

Reusable pipeline for converting pixel art video recordings into properly
formatted sprite sheets for Pocket-Gris creatures.

Usage:
    python3 scripts/extract_sprites.py \\
        --input "AGENTS/content-in/animations/Gris traverse.mp4" \\
        --output Resources/Sprites/gris/walk-left \\
        --start 0.5 --end 4 \\
        --detect-cycle \\
        --verbose
"""

import argparse
import math
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def ensure_venv():
    """Auto-bootstrap a venv with dependencies on first run."""
    venv_dir = Path(__file__).parent / ".venv"
    venv_python = venv_dir / "bin" / "python3"
    requirements = Path(__file__).parent / "requirements-sprites.txt"

    # Already running inside the venv
    if sys.prefix != sys.base_prefix:
        return

    if not venv_python.exists():
        print(f"[setup] Creating venv at {venv_dir}...")
        subprocess.check_call([sys.executable, "-m", "venv", str(venv_dir)])
        print("[setup] Installing dependencies...")
        subprocess.check_call([
            str(venv_python), "-m", "pip", "install", "-q",
            "-r", str(requirements),
        ])

    # Re-exec under venv Python
    os.execv(str(venv_python), [str(venv_python)] + sys.argv)


ensure_venv()

from PIL import Image  # noqa: E402


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args():
    p = argparse.ArgumentParser(
        description="Extract sprite frames from MP4 pixel art animations.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    p.add_argument("--input", "-i", required=True, help="Input video file")
    p.add_argument("--output", "-o", required=True, help="Output directory for frames")
    p.add_argument("--start", type=float, default=0, help="Start time in seconds (default: 0)")
    p.add_argument("--end", type=float, default=None, help="End time in seconds (default: video end)")
    p.add_argument("--detect-cycle", action="store_true", help="Detect one repeating walk cycle")
    p.add_argument("--cycle-threshold", type=float, default=0.85, help="Similarity threshold for cycle detection (default: 0.85)")
    p.add_argument("--target-size", default=None, help="Force output dimensions, e.g. 256x512")
    p.add_argument("--padding", type=int, default=8, help="Pixels around auto-cropped sprite (default: 8)")
    p.add_argument("--sample-rate", type=int, default=1, help="Take every Nth source frame (default: 1)")
    p.add_argument("--keep-temp", action="store_true", help="Keep temp frames for debugging")
    p.add_argument("--dry-run", action="store_true", help="Show what would be done without writing output")
    p.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    return p.parse_args()


def log(msg, verbose_only=False, *, verbose=False):
    if verbose_only and not verbose:
        return
    print(msg)


# ---------------------------------------------------------------------------
# Stage 1: Frame Extraction (ffmpeg)
# ---------------------------------------------------------------------------

def extract_frames(input_path, temp_dir, start, end, verbose=False):
    """Extract frames from video using ffmpeg."""
    log("[stage 1] Extracting frames with ffmpeg...", verbose=verbose)

    cmd = ["ffmpeg", "-y"]
    if start > 0:
        cmd += ["-ss", str(start)]
    if end is not None:
        cmd += ["-to", str(end)]
    cmd += ["-i", str(input_path), "-vsync", "cfr"]
    cmd += [str(Path(temp_dir) / "frame_%06d.png")]

    log(f"  cmd: {' '.join(cmd)}", verbose_only=True, verbose=verbose)

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"[error] ffmpeg failed:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)

    frames = sorted(Path(temp_dir).glob("frame_*.png"))
    log(f"  Extracted {len(frames)} raw frames", verbose=verbose)
    return frames


def subsample_frames(frames, sample_rate):
    """Take every Nth frame."""
    if sample_rate <= 1:
        return frames
    return frames[::sample_rate]


def load_frames(frame_paths, verbose=False):
    """Load extracted frame files as RGBA PIL Images."""
    log("[stage 2] Loading frames...", verbose=verbose)
    images = []
    for p in frame_paths:
        images.append(Image.open(p).convert("RGBA"))
    log(f"  Loaded {len(images)} frames", verbose=verbose)
    return images


# ---------------------------------------------------------------------------
# Stage 3: Sprite Position Tracking
# ---------------------------------------------------------------------------

def track_positions(rgba_frames, verbose=False):
    """Find bounding box of non-transparent pixels per frame.

    Returns list of dicts with cx, cy, w, h, bbox (or None if frame is empty).
    """
    log("[stage 3] Tracking sprite positions...", verbose=verbose)

    positions = []
    for img in rgba_frames:
        bbox = img.getbbox()
        if bbox is None:
            positions.append(None)
            continue
        x0, y0, x1, y1 = bbox
        w = x1 - x0
        h = y1 - y0
        cx = (x0 + x1) / 2
        cy = (y0 + y1) / 2
        positions.append({"cx": cx, "cy": cy, "w": w, "h": h, "bbox": bbox})

    non_empty = [p for p in positions if p is not None]
    if non_empty:
        max_w = max(p["w"] for p in non_empty)
        max_h = max(p["h"] for p in non_empty)
        log(f"  Max sprite dimensions: {max_w}x{max_h}", verbose_only=True, verbose=verbose)
    else:
        log("  [warn] All frames are empty!", verbose=verbose)

    return positions


# ---------------------------------------------------------------------------
# Stage 4: Position Normalization
# ---------------------------------------------------------------------------

def normalize_positions(rgba_frames, positions, padding, verbose=False):
    """Strip horizontal translation, center horizontally, bottom-align vertically.

    Returns list of RGBA images on uniform canvas.
    """
    log("[stage 4] Normalizing positions...", verbose=verbose)

    non_empty = [(i, p) for i, p in enumerate(positions) if p is not None]
    if not non_empty:
        return rgba_frames

    max_w = max(p["w"] for _, p in non_empty) + padding * 2
    max_h = max(p["h"] for _, p in non_empty) + padding * 2

    # Make dimensions even
    max_w += max_w % 2
    max_h += max_h % 2

    normalized = []
    for i, img in enumerate(rgba_frames):
        pos = positions[i]
        if pos is None:
            normalized.append(Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0)))
            continue

        # Crop sprite from original
        x0, y0, x1, y1 = pos["bbox"]
        sprite = img.crop((x0, y0, x1, y1))
        sw, sh = sprite.size

        # Create canvas and paste: center horizontally, bottom-align vertically
        canvas = Image.new("RGBA", (max_w, max_h), (0, 0, 0, 0))
        paste_x = (max_w - sw) // 2
        paste_y = max_h - sh - padding  # bottom-align with padding
        canvas.paste(sprite, (paste_x, paste_y))
        normalized.append(canvas)

    log(f"  Normalized to {max_w}x{max_h} canvas", verbose=verbose)
    return normalized


# ---------------------------------------------------------------------------
# Stage 5: Walk Cycle Detection
# ---------------------------------------------------------------------------

def frame_signature(img, sig_size=(32, 64)):
    """Downsample frame to a small signature for comparison.

    Crops to the content bounding box first so that the signature
    captures sprite detail rather than empty canvas.
    """
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    small = img.resize(sig_size, Image.NEAREST)
    return list(small.getdata())


def frame_similarity(sig_a, sig_b):
    """Compare two frame signatures. Returns 0-1 similarity score."""
    if len(sig_a) != len(sig_b):
        return 0

    total = 0
    matches = 0
    for pa, pb in zip(sig_a, sig_b):
        # Compare RGBA channels
        ra, ga, ba, aa = pa
        rb, gb, bb, ab = pb

        # Both transparent — match
        if aa == 0 and ab == 0:
            matches += 1
            total += 1
            continue

        # One transparent, one not — no match
        if (aa == 0) != (ab == 0):
            total += 1
            continue

        # Both opaque — compare RGB distance
        dist = math.sqrt((ra - rb) ** 2 + (ga - gb) ** 2 + (ba - bb) ** 2)
        max_dist = math.sqrt(3 * 255 ** 2)
        matches += 1 - (dist / max_dist)
        total += 1

    return matches / total if total > 0 else 0


def detect_cycle(frames, threshold, verbose=False):
    """Find one repeating walk cycle.

    Uses auto-correlation of consecutive frame differences to find the
    cycle period. Steps:
    1. Compute similarity between each pair of adjacent frames.
    2. This creates a signal that should be periodic (the walk cycle).
    3. Auto-correlate the signal to find the period.
    4. Validate by checking frame-to-frame similarity at that offset.

    Falls back to direct frame comparison if auto-correlation fails.

    Returns indices of frames in one cycle, or None if no cycle found.
    """
    log("[stage 5] Detecting walk cycle...", verbose=verbose)

    if len(frames) < 6:
        log("  Not enough frames for cycle detection", verbose=verbose)
        return None

    sigs = [frame_signature(f) for f in frames]
    n = len(sigs)

    # Method 1: Direct comparison — find the first frame (after min_cycle)
    # that is a local maximum in similarity to frame 0
    min_cycle = max(4, n // 10)
    ref_sig = sigs[0]
    similarities = []
    for i in range(n):
        sim = frame_similarity(ref_sig, sigs[i])
        similarities.append(sim)

    # Find local maxima in the similarity curve after min_cycle
    cycle_len = None
    best_sim = 0
    for i in range(min_cycle, n - 1):
        sim = similarities[i]
        # Check for local maximum (higher than neighbors)
        if sim > similarities[i - 1] and sim > similarities[i + 1]:
            if sim >= threshold and sim > best_sim:
                cycle_len = i
                best_sim = sim
                break  # take the first peak above threshold
        log(f"  Frame 0 vs {i}: similarity={sim:.3f}", verbose_only=True, verbose=verbose)

    if cycle_len is not None:
        log(f"  Found cycle at frame {cycle_len} (similarity={best_sim:.3f})", verbose=verbose)
    else:
        # Method 2: Auto-correlation of consecutive-frame differences
        log("  Direct comparison didn't find cycle; trying auto-correlation...",
            verbose_only=True, verbose=verbose)
        diff_signal = []
        for i in range(n - 1):
            diff_signal.append(frame_similarity(sigs[i], sigs[i + 1]))

        # Auto-correlate to find period
        signal_len = len(diff_signal)
        best_corr = -1
        for period in range(min_cycle, signal_len // 2):
            corr = 0
            count = 0
            for j in range(signal_len - period):
                corr += diff_signal[j] * diff_signal[j + period]
                count += 1
            if count > 0:
                corr /= count
                if corr > best_corr:
                    best_corr = corr
                    cycle_len = period

        if cycle_len and best_corr > 0:
            log(f"  Auto-correlation peak at period={cycle_len} (corr={best_corr:.3f})",
                verbose_only=True, verbose=verbose)
            # Validate: compare frame pairs at this offset
            match_count = 0
            total = min(n - cycle_len, cycle_len * 2)
            for j in range(total):
                sim = frame_similarity(sigs[j], sigs[j + cycle_len])
                if sim >= threshold * 0.85:
                    match_count += 1
            match_rate = match_count / total if total > 0 else 0
            if match_rate < 0.5:
                log(f"  [warn] Cycle validation failed (match_rate={match_rate:.2f}); using all frames",
                    verbose=verbose)
                cycle_len = None
            else:
                log(f"  Cycle validated (match_rate={match_rate:.2f})", verbose=verbose)
        else:
            cycle_len = None

    if cycle_len is None:
        log("  [warn] No cycle detected; using all frames", verbose=verbose)
        return None

    log(f"  Detected cycle: {cycle_len} frames", verbose=verbose)
    return list(range(cycle_len))


# ---------------------------------------------------------------------------
# Stage 6: Auto-Crop & Resize
# ---------------------------------------------------------------------------

def autocrop_and_resize(frames, padding, target_size, verbose=False):
    """Union bounding box across frames, crop, pad, and resize.

    Returns list of final RGBA images.
    """
    log("[stage 6] Auto-cropping and resizing...", verbose=verbose)

    # Find union bounding box
    union_bbox = None
    for img in frames:
        bbox = img.getbbox()
        if bbox is None:
            continue
        if union_bbox is None:
            union_bbox = list(bbox)
        else:
            union_bbox[0] = min(union_bbox[0], bbox[0])
            union_bbox[1] = min(union_bbox[1], bbox[1])
            union_bbox[2] = max(union_bbox[2], bbox[2])
            union_bbox[3] = max(union_bbox[3], bbox[3])

    if union_bbox is None:
        log("  [warn] All frames empty after cropping", verbose=verbose)
        return frames

    # Apply padding
    x0 = max(0, union_bbox[0] - padding)
    y0 = max(0, union_bbox[1] - padding)
    x1 = min(frames[0].width, union_bbox[2] + padding)
    y1 = min(frames[0].height, union_bbox[3] + padding)

    cropped = [img.crop((x0, y0, x1, y1)) for img in frames]
    cw, ch = cropped[0].size
    log(f"  Cropped to {cw}x{ch}", verbose_only=True, verbose=verbose)

    # Resize if target specified
    if target_size:
        tw, th = target_size
        cropped = [img.resize((tw, th), Image.NEAREST) for img in cropped]
        log(f"  Resized to {tw}x{th} (nearest-neighbor)", verbose=verbose)
    else:
        # Ensure even dimensions
        ew = cw + cw % 2
        eh = ch + ch % 2
        if ew != cw or eh != ch:
            new_cropped = []
            for img in cropped:
                canvas = Image.new("RGBA", (ew, eh), (0, 0, 0, 0))
                canvas.paste(img, (0, 0))
                new_cropped.append(canvas)
            cropped = new_cropped
            log(f"  Padded to even dimensions: {ew}x{eh}", verbose_only=True, verbose=verbose)

    return cropped


# ---------------------------------------------------------------------------
# Stage 7: Output
# ---------------------------------------------------------------------------

def save_frames(frames, output_dir, source_fps, cycle_len, dry_run=False, verbose=False):
    """Save frames as frame-001.png, frame-002.png, etc."""
    log("[stage 7] Saving output...", verbose=verbose)

    if not frames:
        log("  [error] No frames to save!", verbose=verbose)
        return

    output_path = Path(output_dir)

    if dry_run:
        log(f"  [dry-run] Would save {len(frames)} frames to {output_path}/", verbose=verbose)
    else:
        output_path.mkdir(parents=True, exist_ok=True)
        for i, img in enumerate(frames):
            out_file = output_path / f"frame-{i + 1:03d}.png"
            img.save(out_file, "PNG")

    w, h = frames[0].size

    # Suggest a reasonable FPS for sprite animation (typically 8-12)
    rec_fps = source_fps
    if rec_fps > 12:
        suggested_fps = max(8, rec_fps // 3)
    else:
        suggested_fps = rec_fps

    anim_name = output_path.name
    print(f"\n{'[dry-run] ' if dry_run else ''}Extracted {len(frames)} frames to {output_path}/")
    print(f"  Dimensions: {w}x{h} RGBA")
    print(f"  Source FPS: {source_fps}")
    print(f'  Recommended: {{"name": "{anim_name}", "frameCount": {len(frames)}, "fps": {suggested_fps}, "looping": true}}')


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def main():
    args = parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[error] Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Check ffmpeg
    if shutil.which("ffmpeg") is None:
        print("[error] ffmpeg not found. Install with: brew install ffmpeg", file=sys.stderr)
        sys.exit(1)

    # Parse target size
    target_size = None
    if args.target_size:
        parts = args.target_size.lower().split("x")
        if len(parts) != 2:
            print(f"[error] Invalid target-size format: {args.target_size} (expected WxH)", file=sys.stderr)
            sys.exit(1)
        target_size = (int(parts[0]), int(parts[1]))

    # Get source FPS
    try:
        probe = subprocess.run(
            ["ffprobe", "-v", "quiet", "-select_streams", "v:0",
             "-show_entries", "stream=r_frame_rate", "-of", "csv=p=0",
             str(input_path)],
            capture_output=True, text=True,
        )
        num, den = probe.stdout.strip().split("/")
        source_fps = int(num) // int(den)
    except Exception:
        source_fps = 24
        log(f"[warn] Could not detect FPS, assuming {source_fps}", verbose=args.verbose)

    log(f"Input: {input_path} ({source_fps} fps)", verbose=args.verbose)
    log(f"Output: {args.output}", verbose=args.verbose)
    log(f"Time range: {args.start}s - {args.end if args.end else 'end'}s", verbose=args.verbose)

    # Stage 1: Extract frames
    temp_dir = tempfile.mkdtemp(prefix="pocket-gris-sprites-")
    try:
        raw_frames = extract_frames(input_path, temp_dir, args.start, args.end, verbose=args.verbose)
        if not raw_frames:
            print("[error] No frames extracted", file=sys.stderr)
            sys.exit(1)

        # Subsample
        raw_frames = subsample_frames(raw_frames, args.sample_rate)
        if args.sample_rate > 1:
            log(f"  After subsampling (every {args.sample_rate}): {len(raw_frames)} frames",
                verbose=args.verbose)
            source_fps = source_fps // args.sample_rate

        # Stage 2: Load frames
        rgba_frames = load_frames(raw_frames, verbose=args.verbose)

        # Stage 3: Track positions
        positions = track_positions(rgba_frames, verbose=args.verbose)

        # Stage 4: Normalize positions
        normalized = normalize_positions(rgba_frames, positions, args.padding, verbose=args.verbose)

        # Stage 5: Cycle detection
        cycle_indices = None
        cycle_len = None
        if args.detect_cycle:
            cycle_indices = detect_cycle(normalized, args.cycle_threshold, verbose=args.verbose)
            if cycle_indices:
                cycle_len = len(cycle_indices)
                normalized = [normalized[i] for i in cycle_indices]

        # Stage 6: Auto-crop & resize
        final_frames = autocrop_and_resize(normalized, args.padding, target_size, verbose=args.verbose)

        # Stage 7: Output
        save_frames(final_frames, args.output, source_fps, cycle_len, dry_run=args.dry_run, verbose=args.verbose)

    finally:
        if args.keep_temp:
            log(f"  Temp frames kept at: {temp_dir}", verbose=args.verbose)
        else:
            shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    main()
