#!/usr/bin/env python3
"""Create a short looping comparison from the two captured app screenshots.

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


def scene(path: Path, max_size: tuple[int, int], crop_bottom: int = 0) -> Image.Image:
    with Image.open(path) as source:
        source = source.convert("RGB")
        if crop_bottom:
            source = source.crop((0, 0, source.width, source.height - crop_bottom))
        source.thumbnail(max_size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", SIZE, "#17181b")
        canvas.paste(source, ((SIZE[0] - source.width) // 2, (SIZE[1] - source.height) // 2))
        return canvas


apple = scene(DOCS / "apple-mode.jpg", (940, 690))
google = scene(DOCS / "google-mode.jpg", (720, 690), crop_bottom=160)
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
