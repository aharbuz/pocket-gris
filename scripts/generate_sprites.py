#!/usr/bin/env python3
"""Generate placeholder sprite frames for Pocket-Gris creatures.

Generates two creatures with full animation coverage for all 5 behaviors:
- Peek (peek-left/right/top/bottom, retreat-left/right/top/bottom)
- Traverse (walk-left, walk-right)
- Stationary (idle)
- Climber (climb)
- Follow / cursorReactive (walk-left, walk-right, idle)

Usage:
    python3 scripts/generate_sprites.py
"""

import json
import math
import os
import struct
import zlib
from pathlib import Path


def create_sprite_with_eyes(width, height, r, g, b, eye_offset_x=0, eye_offset_y=0, mouth_curve=4):
    """Create a sprite with eyes and mouth that can animate."""

    def output_chunk(chunk_type, data):
        chunk = chunk_type + data
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)

    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr = output_chunk(b'IHDR', ihdr_data)

    raw_data = b''
    center_x, center_y = width // 2, height // 2

    for y in range(height):
        raw_data += b'\x00'
        for x in range(width):
            # Body: rounded rectangle
            margin = 6
            corner_radius = 10

            in_body = False
            if margin <= x < width - margin and margin <= y < height - margin:
                if x < margin + corner_radius and y < margin + corner_radius:
                    dx, dy = x - (margin + corner_radius), y - (margin + corner_radius)
                    in_body = dx*dx + dy*dy <= corner_radius*corner_radius
                elif x >= width - margin - corner_radius and y < margin + corner_radius:
                    dx, dy = x - (width - margin - corner_radius), y - (margin + corner_radius)
                    in_body = dx*dx + dy*dy <= corner_radius*corner_radius
                elif x < margin + corner_radius and y >= height - margin - corner_radius:
                    dx, dy = x - (margin + corner_radius), y - (height - margin - corner_radius)
                    in_body = dx*dx + dy*dy <= corner_radius*corner_radius
                elif x >= width - margin - corner_radius and y >= height - margin - corner_radius:
                    dx, dy = x - (width - margin - corner_radius), y - (height - margin - corner_radius)
                    in_body = dx*dx + dy*dy <= corner_radius*corner_radius
                else:
                    in_body = True

            if not in_body:
                raw_data += bytes([0, 0, 0, 0])
                continue

            # Eyes
            eye_radius = 6
            pupil_radius = 3
            eye_y = center_y - 8
            left_eye_x = center_x - 10
            right_eye_x = center_x + 10

            # Left eye
            dx, dy = x - left_eye_x, y - eye_y
            if dx*dx + dy*dy <= eye_radius*eye_radius:
                pdx, pdy = x - (left_eye_x + eye_offset_x), y - (eye_y + eye_offset_y)
                if pdx*pdx + pdy*pdy <= pupil_radius*pupil_radius:
                    raw_data += bytes([30, 30, 30, 255])
                else:
                    raw_data += bytes([255, 255, 255, 255])
                continue

            # Right eye
            dx, dy = x - right_eye_x, y - eye_y
            if dx*dx + dy*dy <= eye_radius*eye_radius:
                pdx, pdy = x - (right_eye_x + eye_offset_x), y - (eye_y + eye_offset_y)
                if pdx*pdx + pdy*pdy <= pupil_radius*pupil_radius:
                    raw_data += bytes([30, 30, 30, 255])
                else:
                    raw_data += bytes([255, 255, 255, 255])
                continue

            # Mouth
            mouth_y = center_y + 12
            mouth_width = 12
            if abs(x - center_x) <= mouth_width and abs(y - mouth_y) <= 3:
                expected_y = mouth_y + int(mouth_curve * ((x - center_x) / mouth_width) ** 2)
                if abs(y - expected_y) <= 1:
                    raw_data += bytes([60, 40, 40, 255])
                    continue

            # Body color with gradient
            shade = int(20 * (y / height))
            raw_data += bytes([min(255, r + shade), min(255, g + shade), min(255, b + shade), 255])

    compressed = zlib.compress(raw_data, 9)
    idat = output_chunk(b'IDAT', compressed)
    iend = output_chunk(b'IEND', b'')

    return signature + ihdr + idat + iend


def generate_animation_frames(base_path, anim_name, frame_count, width, height, base_color, frame_modifier):
    """Generate frames for an animation."""
    anim_path = base_path / anim_name
    anim_path.mkdir(parents=True, exist_ok=True)

    for i in range(frame_count):
        r, g, b = base_color
        eye_x, eye_y, mouth = frame_modifier(i, frame_count)
        png_data = create_sprite_with_eyes(width, height, r, g, b, eye_x, eye_y, mouth)

        frame_file = anim_path / f"frame-{i+1:03d}.png"
        with open(frame_file, 'wb') as f:
            f.write(png_data)

    print(f"  Generated {frame_count} frames for {anim_name}")


# --- Animation modifiers ---

def peek_left_modifier(i, total):
    progress = i / (total - 1) if total > 1 else 0
    if progress < 0.3:
        return (-2, 0, 4)
    elif progress < 0.7:
        return (0, 0, 3)
    else:
        return (0, 1, 2)


def peek_right_modifier(i, total):
    progress = i / (total - 1) if total > 1 else 0
    if progress < 0.3:
        return (2, 0, 4)
    elif progress < 0.7:
        return (0, 0, 3)
    else:
        return (0, 1, 2)


def peek_top_modifier(i, total):
    progress = i / (total - 1) if total > 1 else 0
    if progress < 0.3:
        return (0, -2, 4)
    elif progress < 0.7:
        return (0, 0, 3)
    else:
        return (0, 1, 2)


def peek_bottom_modifier(i, total):
    progress = i / (total - 1) if total > 1 else 0
    if progress < 0.3:
        return (0, 2, 4)
    elif progress < 0.7:
        return (0, 0, 3)
    else:
        return (0, 1, 2)


def retreat_modifier(i, total):
    progress = i / (total - 1) if total > 1 else 0
    if progress < 0.3:
        return (0, -1, 6)
    elif progress < 0.6:
        return (0, 0, 5)
    else:
        return (0, 1, 4)


def idle_modifier(i, total):
    phase = (i / total) * 2 * math.pi
    eye_x = int(2 * math.sin(phase))
    return (eye_x, 0, 3)


def walk_left_modifier(i, total):
    phase = (i / total) * 2 * math.pi
    bounce = int(2 * abs(math.sin(phase * 2)))
    return (-1, bounce - 1, 3)


def walk_right_modifier(i, total):
    phase = (i / total) * 2 * math.pi
    bounce = int(2 * abs(math.sin(phase * 2)))
    return (1, bounce - 1, 3)


def climb_modifier(i, total):
    phase = (i / total) * 2 * math.pi
    eye_y = int(abs(math.sin(phase * 2)))
    return (0, eye_y - 1, 2)


# --- Creature definitions ---

CREATURES = [
    {
        "id": "blob-green",
        "name": "Sprout",
        "personality": "curious",
        "color": (80, 180, 100),
    },
    {
        "id": "blob-purple",
        "name": "Jinx",
        "personality": "mischievous",
        "color": (140, 90, 180),
    },
]

ANIMATIONS = [
    {"name": "idle",           "frames": 8,  "fps": 6,  "looping": True,  "modifier": idle_modifier},
    {"name": "walk-left",      "frames": 8,  "fps": 10, "looping": True,  "modifier": walk_left_modifier},
    {"name": "walk-right",     "frames": 8,  "fps": 10, "looping": True,  "modifier": walk_right_modifier},
    {"name": "climb",          "frames": 8,  "fps": 10, "looping": True,  "modifier": climb_modifier},
    {"name": "peek-left",      "frames": 10, "fps": 12, "looping": False, "modifier": peek_left_modifier},
    {"name": "peek-right",     "frames": 10, "fps": 12, "looping": False, "modifier": peek_right_modifier},
    {"name": "peek-top",       "frames": 10, "fps": 12, "looping": False, "modifier": peek_top_modifier},
    {"name": "peek-bottom",    "frames": 10, "fps": 12, "looping": False, "modifier": peek_bottom_modifier},
    {"name": "retreat-left",   "frames": 8,  "fps": 12, "looping": False, "modifier": retreat_modifier},
    {"name": "retreat-right",  "frames": 8,  "fps": 12, "looping": False, "modifier": retreat_modifier},
    {"name": "retreat-top",    "frames": 8,  "fps": 12, "looping": False, "modifier": retreat_modifier},
    {"name": "retreat-bottom", "frames": 8,  "fps": 12, "looping": False, "modifier": retreat_modifier},
]


def generate_creature(sprites_dir, creature_def):
    """Generate all sprites and manifest for one creature."""
    creature_id = creature_def["id"]
    base_path = sprites_dir / creature_id
    base_path.mkdir(parents=True, exist_ok=True)

    width, height = 64, 64
    color = creature_def["color"]

    print(f"\nGenerating '{creature_id}' ({creature_def['name']})...")

    for anim in ANIMATIONS:
        generate_animation_frames(
            base_path, anim["name"], anim["frames"],
            width, height, color, anim["modifier"]
        )

    manifest = {
        "id": creature_id,
        "name": creature_def["name"],
        "personality": creature_def["personality"],
        "animations": [
            {"name": a["name"], "frameCount": a["frames"], "fps": a["fps"], "looping": a["looping"]}
            for a in ANIMATIONS
        ]
    }

    manifest_path = base_path / "creature.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"  Created manifest at {manifest_path}")


def main():
    sprites_dir = Path(__file__).parent.parent / "Resources" / "Sprites"

    for creature_def in CREATURES:
        generate_creature(sprites_dir, creature_def)

    print("\nDone!")


if __name__ == "__main__":
    main()
