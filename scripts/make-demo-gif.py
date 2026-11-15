#!/usr/bin/env python3
"""Create a short looping comparison from the two train-station screenshots.

Requires Pillow. Run from the repository root with:
    python3 scripts/make-demo-gif.py
"""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "docs" / "images"
SIZE = (960, 720)
FPS = 10
HOLD = 27
FADE = 6
APPLE_IMAGE = IMAGES / "apple-train-station.jpg"
GOOGLE_IMAGE = IMAGES / "google-train-station.jpg"

for image_path in (APPLE_IMAGE, GOOGLE_IMAGE):
    if not image_path.is_file():
        raise SystemExit(f"Missing screenshot: {image_path}")


def scene(path: Path, max_size: tuple[int, int], crop_bottom: int = 0) -> Image.Image:
    with Image.open(path) as source:
        source = source.convert("RGB")
        if crop_bottom:
            source = source.crop((0, 0, source.width, source.height - crop_bottom))
        source.thumbnail(max_size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", SIZE, "#17181b")
        canvas.paste(source, ((SIZE[0] - source.width) // 2, (SIZE[1] - source.height) // 2))
        return canvas


apple = scene(APPLE_IMAGE, (940, 690))
google = scene(GOOGLE_IMAGE, (720, 690), crop_bottom=160)
frames = []
frames.extend([apple] * HOLD)
frames.extend(Image.blend(apple, google, (i + 1) / (FADE + 1)) for i in range(FADE))
frames.extend([google] * HOLD)
frames.extend(Image.blend(google, apple, (i + 1) / (FADE + 1)) for i in range(FADE))

frames[0].save(
    IMAGES / "translation-modes.gif",
    save_all=True,
    append_images=frames[1:],
    duration=1000 // FPS,
    loop=0,
    optimize=True,
    disposal=2,
)
print(f"Saved {IMAGES / 'translation-modes.gif'} ({len(frames) / FPS:.1f} s)")
