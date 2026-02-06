# Extract Sprites Script — Session Summary (2026-02-06)

## What was built
- `scripts/extract_sprites.py` — MP4-to-sprite-frames extraction script
- `scripts/requirements-sprites.txt` — Pillow dependency
- Added `scripts/.venv/` to `.gitignore`

## Current state
The script has a full 7-stage pipeline (ffmpeg extraction, bg removal, position tracking, normalization, cycle detection, auto-crop, output). Background removal uses flood-fill from edges and works well for the checkerboard video, but the user decided to handle background removal manually at the sprite sheet phase instead.

## Key findings from testing
- Video: 1280x720, 24fps, H.264, 8s duration
- Checkerboard background: light=251, dark=173, cell=25px
- Sprite is ~460x520px after extraction
- Walk cycle detected at 9 frames (threshold 0.7)
- H.264 compression causes chroma noise on achromatic pixels (channel spread up to ~10)
- Background removal via flood-fill from edges was the winning approach (per-pixel alone left stray artifacts)

## Next steps
1. Simplify script: remove background removal stages, focus on frame extraction + cycle detection + crop/resize
2. Run against the real video to produce final frames
3. User will manually remove checkerboard background from the sprite sheet
4. Create `Resources/Sprites/gris/creature.json` for the new creature
5. Existing "gris" creature has generated placeholder sprites — the new pig sprite is distinct

## Files modified
- `scripts/extract_sprites.py` (new)
- `scripts/requirements-sprites.txt` (new)
- `.gitignore` (added scripts/.venv/)
