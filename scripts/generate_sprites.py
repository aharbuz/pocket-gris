#!/usr/bin/env python3
"""Generate placeholder sprite frames for testing."""

import os
from pathlib import Path

def create_png(width, height, r, g, b, alpha=255):
    """Create a simple PNG with a colored rectangle."""
    import struct
    import zlib

    def output_chunk(chunk_type, data):
        chunk = chunk_type + data
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', zlib.crc32(chunk) & 0xffffffff)

    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'

    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)  # 8-bit RGBA
    ihdr = output_chunk(b'IHDR', ihdr_data)

    # IDAT chunk (image data)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # filter type: none
        for x in range(width):
            # Simple shape: rounded rectangle with border
            border = 4
            inner = border < x < width - border and border < y < height - border
            if inner:
                raw_data += bytes([r, g, b, alpha])
            elif x < border or x >= width - border or y < border or y >= height - border:
                # Border
                raw_data += bytes([max(0, r - 50), max(0, g - 50), max(0, b - 50), alpha])
            else:
                raw_data += bytes([0, 0, 0, 0])  # transparent

    compressed = zlib.compress(raw_data, 9)
    idat = output_chunk(b'IDAT', compressed)

    # IEND chunk
    iend = output_chunk(b'IEND', b'')

    return signature + ihdr + idat + iend


def create_sprite_with_eyes(width, height, r, g, b, eye_offset_x=0, eye_offset_y=0, mouth_curve=4):
    """Create a sprite with eyes and mouth that can animate."""
    import struct
    import zlib

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

            # Check if inside rounded rectangle
            in_body = False
            if margin <= x < width - margin and margin <= y < height - margin:
                # Check corners
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
                raw_data += bytes([0, 0, 0, 0])  # transparent
                continue

            # Eyes (two circles)
            eye_radius = 6
            pupil_radius = 3
            eye_y = center_y - 8
            left_eye_x = center_x - 10
            right_eye_x = center_x + 10

            # Left eye white
            dx, dy = x - left_eye_x, y - eye_y
            if dx*dx + dy*dy <= eye_radius*eye_radius:
                # Left pupil
                pdx, pdy = x - (left_eye_x + eye_offset_x), y - (eye_y + eye_offset_y)
                if pdx*pdx + pdy*pdy <= pupil_radius*pupil_radius:
                    raw_data += bytes([30, 30, 30, 255])  # dark pupil
                else:
                    raw_data += bytes([255, 255, 255, 255])  # white
                continue

            # Right eye white
            dx, dy = x - right_eye_x, y - eye_y
            if dx*dx + dy*dy <= eye_radius*eye_radius:
                # Right pupil
                pdx, pdy = x - (right_eye_x + eye_offset_x), y - (eye_y + eye_offset_y)
                if pdx*pdx + pdy*pdy <= pupil_radius*pupil_radius:
                    raw_data += bytes([30, 30, 30, 255])  # dark pupil
                else:
                    raw_data += bytes([255, 255, 255, 255])  # white
                continue

            # Mouth (curved line)
            mouth_y = center_y + 12
            mouth_width = 12
            if abs(x - center_x) <= mouth_width and abs(y - mouth_y) <= 3:
                # Simple curved mouth
                expected_y = mouth_y + int(mouth_curve * ((x - center_x) / mouth_width) ** 2)
                if abs(y - expected_y) <= 1:
                    raw_data += bytes([60, 40, 40, 255])  # mouth color
                    continue

            # Body color with slight gradient
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


def main():
    base_path = Path(__file__).parent.parent / "Resources" / "Sprites" / "gris"
    base_path.mkdir(parents=True, exist_ok=True)

    width, height = 64, 64
    base_color = (80, 180, 100)  # Green

    print("Generating sprite frames for 'gris' creature...")

    # Peek animations: eyes look in direction, then look at viewer
    def peek_left_modifier(i, total):
        progress = i / (total - 1) if total > 1 else 0
        if progress < 0.3:
            return (-2, 0, 4)  # Looking left
        elif progress < 0.7:
            return (0, 0, 3)   # Looking at viewer
        else:
            return (0, 1, 2)   # Slight smile

    def peek_right_modifier(i, total):
        progress = i / (total - 1) if total > 1 else 0
        if progress < 0.3:
            return (2, 0, 4)   # Looking right
        elif progress < 0.7:
            return (0, 0, 3)   # Looking at viewer
        else:
            return (0, 1, 2)   # Slight smile

    def peek_top_modifier(i, total):
        progress = i / (total - 1) if total > 1 else 0
        if progress < 0.3:
            return (0, -2, 4)  # Looking up
        elif progress < 0.7:
            return (0, 0, 3)   # Looking at viewer
        else:
            return (0, 1, 2)   # Slight smile

    def peek_bottom_modifier(i, total):
        progress = i / (total - 1) if total > 1 else 0
        if progress < 0.3:
            return (0, 2, 4)   # Looking down
        elif progress < 0.7:
            return (0, 0, 3)   # Looking at viewer
        else:
            return (0, 1, 2)   # Slight smile

    # Retreat animations: look alarmed then retreat
    def retreat_modifier(i, total):
        progress = i / (total - 1) if total > 1 else 0
        if progress < 0.3:
            return (0, -1, 6)  # Surprised
        elif progress < 0.6:
            return (0, 0, 5)   # Still surprised
        else:
            return (0, 1, 4)   # Retreating

    # Idle: gentle eye movement
    def idle_modifier(i, total):
        import math
        phase = (i / total) * 2 * math.pi
        eye_x = int(2 * math.sin(phase))
        return (eye_x, 0, 3)

    # Walk left: eyes look forward-left, slight bounce in mouth
    def walk_left_modifier(i, total):
        import math
        phase = (i / total) * 2 * math.pi
        bounce = int(2 * abs(math.sin(phase * 2)))  # Bouncy walk
        return (-1, bounce - 1, 3)  # Looking left while walking

    # Walk right: eyes look forward-right, slight bounce
    def walk_right_modifier(i, total):
        import math
        phase = (i / total) * 2 * math.pi
        bounce = int(2 * abs(math.sin(phase * 2)))
        return (1, bounce - 1, 3)  # Looking right while walking

    # Climb: concentrated look, slight exertion
    def climb_modifier(i, total):
        import math
        phase = (i / total) * 2 * math.pi
        # Eyes focused, small bounce for climbing motion
        eye_y = int(abs(math.sin(phase * 2)))
        return (0, eye_y - 1, 2)  # Concentrated expression

    # Generate all animations
    generate_animation_frames(base_path, "peek-left", 10, width, height, base_color, peek_left_modifier)
    generate_animation_frames(base_path, "peek-right", 10, width, height, base_color, peek_right_modifier)
    generate_animation_frames(base_path, "peek-top", 10, width, height, base_color, peek_top_modifier)
    generate_animation_frames(base_path, "peek-bottom", 10, width, height, base_color, peek_bottom_modifier)
    generate_animation_frames(base_path, "retreat-left", 8, width, height, base_color, retreat_modifier)
    generate_animation_frames(base_path, "retreat-right", 8, width, height, base_color, retreat_modifier)
    generate_animation_frames(base_path, "retreat-top", 8, width, height, base_color, retreat_modifier)
    generate_animation_frames(base_path, "retreat-bottom", 8, width, height, base_color, retreat_modifier)
    generate_animation_frames(base_path, "idle", 8, width, height, base_color, idle_modifier)
    generate_animation_frames(base_path, "walk-left", 8, width, height, base_color, walk_left_modifier)
    generate_animation_frames(base_path, "walk-right", 8, width, height, base_color, walk_right_modifier)
    generate_animation_frames(base_path, "climb", 8, width, height, base_color, climb_modifier)

    # Create creature manifest
    manifest = {
        "id": "gris",
        "name": "Gris",
        "personality": "curious",
        "animations": [
            {"name": "peek-left", "frameCount": 10, "fps": 12, "looping": False},
            {"name": "peek-right", "frameCount": 10, "fps": 12, "looping": False},
            {"name": "peek-top", "frameCount": 10, "fps": 12, "looping": False},
            {"name": "peek-bottom", "frameCount": 10, "fps": 12, "looping": False},
            {"name": "retreat-left", "frameCount": 8, "fps": 12, "looping": False},
            {"name": "retreat-right", "frameCount": 8, "fps": 12, "looping": False},
            {"name": "retreat-top", "frameCount": 8, "fps": 12, "looping": False},
            {"name": "retreat-bottom", "frameCount": 8, "fps": 12, "looping": False},
            {"name": "idle", "frameCount": 8, "fps": 6, "looping": True},
            {"name": "walk-left", "frameCount": 8, "fps": 10, "looping": True},
            {"name": "walk-right", "frameCount": 8, "fps": 10, "looping": True},
            {"name": "climb", "frameCount": 8, "fps": 10, "looping": True}
        ]
    }

    import json
    manifest_path = base_path / "creature.json"
    with open(manifest_path, 'w') as f:
        json.dump(manifest, f, indent=2)

    print(f"Created manifest at {manifest_path}")
    print("Done!")


if __name__ == "__main__":
    main()
