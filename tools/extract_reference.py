"""Decode uploaded footage without interpolating frames; requires av and Pillow."""
import argparse
import json
from pathlib import Path

import av


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", type=Path)
    parser.add_argument("--output", type=Path, default=Path("visual-reports/phoenix-reference"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    with av.open(str(args.video)) as container:
        stream = container.streams.video[0]
        samples = []
        for index, frame in enumerate(container.decode(video=0)):
            if frame.time is None:
                raise ValueError("A decoded frame is missing its presentation timestamp")
            if frame.rotation != 0:
                raise ValueError("Rotate the frame coordinates explicitly before using this source")
            name = f"frame-{index:03d}.png"
            frame.to_image().save(args.output / name)
            samples.append({"frame": index, "seconds": frame.time, "pts": frame.pts, "file": name})
        if not samples or any(b["seconds"] <= a["seconds"] for a, b in zip(samples, samples[1:])):
            raise ValueError("Expected strictly increasing presentation timestamps")
        manifest = {"source": args.video.name, "width": stream.width, "height": stream.height,
                    "average_fps": str(stream.average_rate), "time_base": str(stream.time_base),
                    "frames": samples}
        (args.output / "frames.json").write_text(json.dumps(manifest, indent=2))
        print(f"Decoded {len(samples)} frames with native presentation timestamps into {args.output}")


if __name__ == "__main__":
    main()
