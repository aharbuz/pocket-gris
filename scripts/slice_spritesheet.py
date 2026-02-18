#!/usr/bin/env python3
"""Slice horizontal sprite sheets into individual frame PNGs.

Designed for sprite packs where each animation is a single PNG with
frames laid out left-to-right at equal widths.

Usage:
    python3 scripts/slice_spritesheet.py \\
        --input catset/Cat-Orange-Walk.png \\
        --output Resources/Sprites/cat-orange/walk-right \\
        --frame-width 32 --frame-height 32 --frame-count 8

    # Generate a horizontally flipped copy (e.g. walk-left from walk-right):
    python3 scripts/slice_spritesheet.py \\
        --input catset/Cat-Orange-Walk.png \\
        --output Resources/Sprites/cat-orange/walk-left \\
        --frame-width 32 --frame-height 32 --frame-count 8 \\
        --flip

    # Batch mode: process multiple animations from a config file
    python3 scripts/slice_spritesheet.py --batch config.json
"""

import argparse
import json
import os
import sys
from pathlib import Path


def ensure_pillow():
    """Check Pillow is available, suggest install if not."""
    try:
        from PIL import Image  # noqa: F401
        return True
    except ImportError:
        print("Pillow is required. Install with: pip3 install Pillow", file=sys.stderr)
        sys.exit(1)


def slice_sheet(input_path, output_dir, frame_width, frame_height, frame_count, flip=False, scale=None):
    """Slice a horizontal sprite sheet into individual frame PNGs."""
    from PIL import Image

    img = Image.open(input_path).convert("RGBA")

    # Validate dimensions
    expected_width = frame_width * frame_count
    if img.width < expected_width:
        print(f"Warning: image width {img.width} < expected {expected_width} "
              f"({frame_count} frames x {frame_width}px)", file=sys.stderr)
    if img.height < frame_height:
        print(f"Warning: image height {img.height} < expected {frame_height}px", file=sys.stderr)

    os.makedirs(output_dir, exist_ok=True)

    for i in range(frame_count):
        x = i * frame_width
        box = (x, 0, x + frame_width, frame_height)
        frame = img.crop(box)

        if flip:
            frame = frame.transpose(Image.FLIP_LEFT_RIGHT)

        if scale and scale != 1:
            new_w = int(frame_width * scale)
            new_h = int(frame_height * scale)
            frame = frame.resize((new_w, new_h), Image.NEAREST)

        frame_path = os.path.join(output_dir, f"frame-{i+1:03d}.png")
        frame.save(frame_path)

    print(f"  {frame_count} frames -> {output_dir}"
          f"{' (flipped)' if flip else ''}"
          f"{f' (scale {scale}x)' if scale and scale != 1 else ''}")


def process_batch(config_path):
    """Process multiple animations from a JSON config file.

    Config format:
    {
        "source_dir": "path/to/spritesheet/pngs",
        "output_base": "Resources/Sprites",
        "frame_width": 32,
        "frame_height": 32,
        "scale": 2,
        "creatures": [
            {
                "id": "cat-orange",
                "source_prefix": "Cat-1",
                "animations": [
                    { "source": "Idle.png", "name": "idle", "frames": 4 },
                    { "source": "Walk.png", "name": "walk-right", "frames": 8 },
                    { "source": "Walk.png", "name": "walk-left", "frames": 8, "flip": true },
                    { "source": "Wallclimb.png", "name": "climb", "frames": 6 }
                ]
            }
        ]
    }
    """
    with open(config_path) as f:
        config = json.load(f)

    source_dir = Path(config.get("source_dir", "."))
    output_base = Path(config.get("output_base", "Resources/Sprites"))
    default_fw = config["frame_width"]
    default_fh = config["frame_height"]
    default_scale = config.get("scale")

    for creature in config["creatures"]:
        creature_id = creature["id"]
        prefix = creature.get("source_prefix", "")
        print(f"\nProcessing {creature_id}:")

        for anim in creature["animations"]:
            source_file = anim["source"]
            if prefix:
                input_path = source_dir / f"{prefix}-{source_file}"
                if not input_path.exists():
                    input_path = source_dir / prefix / source_file
            else:
                input_path = source_dir / source_file

            if not input_path.exists():
                print(f"  SKIP {source_file}: not found at {input_path}", file=sys.stderr)
                continue

            fw = anim.get("frame_width", default_fw)
            fh = anim.get("frame_height", default_fh)
            scale = anim.get("scale", default_scale)
            output_dir = output_base / creature_id / anim["name"]

            slice_sheet(
                str(input_path),
                str(output_dir),
                fw, fh,
                anim["frames"],
                flip=anim.get("flip", False),
                scale=scale,
            )


def main():
    parser = argparse.ArgumentParser(description="Slice horizontal sprite sheets into frame PNGs")

    parser.add_argument("--batch", metavar="CONFIG",
                        help="Process multiple animations from a JSON config file")
    parser.add_argument("--input", "-i", metavar="FILE",
                        help="Input sprite sheet PNG")
    parser.add_argument("--output", "-o", metavar="DIR",
                        help="Output directory for frames")
    parser.add_argument("--frame-width", "-W", type=int,
                        help="Width of each frame in pixels")
    parser.add_argument("--frame-height", "-H", type=int,
                        help="Height of each frame in pixels")
    parser.add_argument("--frame-count", "-n", type=int,
                        help="Number of frames in the sheet")
    parser.add_argument("--flip", action="store_true",
                        help="Horizontally flip each frame (e.g. walk-right -> walk-left)")
    parser.add_argument("--scale", "-s", type=float, default=None,
                        help="Scale factor (e.g. 2 for 2x upscale, uses nearest-neighbor)")

    args = parser.parse_args()

    ensure_pillow()

    if args.batch:
        process_batch(args.batch)
        return

    if not all([args.input, args.output, args.frame_width, args.frame_height, args.frame_count]):
        parser.error("Either --batch or all of --input, --output, --frame-width, "
                     "--frame-height, --frame-count are required")

    if not os.path.exists(args.input):
        parser.error(f"Input file not found: {args.input}")

    slice_sheet(
        args.input, args.output,
        args.frame_width, args.frame_height, args.frame_count,
        flip=args.flip,
        scale=args.scale,
    )


if __name__ == "__main__":
    main()
