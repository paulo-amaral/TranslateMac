#!/usr/bin/env python3
"""Create a short looping demo from the two user-provided app screenshots.

Requires Pillow. Run from the repository root with:
    python3 scripts/make-demo-gif.py
"""

from pathlib import Path
from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
SIZE = (960, 720)
FPS = 10
HOLD = 27
FADE = 6
APPLE_IMAGE = DOCS / "apple-empty.png"
GOOGLE_IMAGE = DOCS / "google-result.png"

for image_path in (APPLE_IMAGE, GOOGLE_IMAGE):
    if not image_path.is_file():
        raise SystemExit(f"Missing screenshot: {image_path}")


def scene(path: Path, max_size: tuple[int, int]) -> Image.Image:
    with Image.open(path) as source:
        source = source.convert("RGB")
        source.thumbnail(max_size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", SIZE, "#17181b")
        canvas.paste(source, ((SIZE[0] - source.width) // 2, (SIZE[1] - source.height) // 2))
        return canvas


apple = scene(APPLE_IMAGE, (940, 690))
google = scene(GOOGLE_IMAGE, (720, 690))
frames = []
frames.extend([apple] * HOLD)
frames.extend(Image.blend(apple, google, (i + 1) / (FADE + 1)) for i in range(FADE))
frames.extend([google] * HOLD)
frames.extend(Image.blend(google, apple, (i + 1) / (FADE + 1)) for i in range(FADE))

frames[0].save(
    DOCS / "translation-modes.gif",
    save_all=True,
    append_images=frames[1:],
    duration=1000 // FPS,
    loop=0,
    optimize=True,
    disposal=2,
)
print(f"Saved {DOCS / 'translation-modes.gif'} ({len(frames) / FPS:.1f} s)")
