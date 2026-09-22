"""Compare fixed fire crops; diagnostic measurements are not a parity score."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "visual-reports/fire-reference"
BEFORE = ROOT / "visual-reports/fire-before"
REF = ROOT / "visual-reports/phoenix-reference"
FRAMES = (0, 12, 30, 60)
# One fixed crop for every timestamp. Reference is scaled to the capture size.
CROP = (150, 440, 390, 680)


def main():
    sheet = Image.new("RGB", (720, len(FRAMES) * 270), "#101820")
    draw = ImageDraw.Draw(sheet)
    metrics = []
    for row, frame in enumerate(FRAMES):
        images = [
            Image.open(REF / f"frame-{56 + frame:03d}.png").convert("RGB").resize((589, 1280)),
            Image.open(BEFORE / f"frame-{frame:03d}.png").convert("RGB"),
            Image.open(OUT / f"frame-{frame:03d}.png").convert("RGB"),
        ]
        record = {"pair": frame, "crop": CROP}
        for col, (label, image) in enumerate(zip(("Reference", "Before", "After"), images)):
            crop = image.crop(CROP)
            sheet.paste(crop, (col * 240, row * 270 + 30))
            draw.text((col * 240 + 8, row * 270 + 8), f"{label} / {frame}", fill="white")
            pixels = list(crop.get_flattened_data())
            # Tracks loss of color detail only. A smaller number is not necessarily
            # closer to reference; scene, hull and overlapping effects differ.
            record[label.lower() + "_white_fraction"] = sum(
                min(p) >= 245 for p in pixels
            ) / len(pixels)
        metrics.append(record)
    sheet.save(OUT / "fire-detail-review.png")
    (OUT / "fire-detail-metrics.json").write_text(json.dumps(metrics, indent=2) + "\n")
    print(json.dumps(metrics, indent=2))


if __name__ == "__main__":
    main()
