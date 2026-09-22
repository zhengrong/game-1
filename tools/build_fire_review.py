"""Build a local paired viewer from the actual reference-timed Godot capture."""
import json
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "visual-reports/fire-reference"
REF = ROOT / "visual-reports/phoenix-reference"


def main():
    # Video output is optional so the HTML viewer needs only standard Python.
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video", action="store_true", help="Also export an exact-timestamp comparison MP4 (requires av/Pillow)")
    args = parser.parse_args()
    ours = json.loads((OUT / "frames.json").read_text())
    reference = json.loads((REF / "frames.json").read_text())
    onset = reference["frames"][ours["reference_start"]]["seconds"]
    pairs = []
    for frame in ours["frames"]:
        target = reference["frames"][frame["reference_frame"]]
        error = frame["seconds"] - (target["seconds"] - onset)
        if abs(error) > 0.00001:
            raise ValueError(f"Timestamp mismatch at {frame['frame']}: {error}")
        if not (OUT / frame["file"]).is_file() or not (REF / target["file"]).is_file():
            raise ValueError("A paired image is missing")
        pairs.append({"ours": frame["file"], "reference": "../phoenix-reference/" + target["file"],
                      "seconds": frame["seconds"], "source_seconds": target["seconds"],
                      "reference_frame": target["frame"]})
    data = json.dumps(pairs).replace("<", "\\u003c")
    page = '''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Uploaded Phoenix 2 fire — exact timestamp pairs</title>
<style>body{background:#0c131c;color:#e2ecf6;font:16px system-ui;margin:24px auto;max-width:1100px;padding:0 16px}p{line-height:1.5}.pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}figure{margin:0}img{width:100%;height:72vh;object-fit:contain;background:#05080c}input{width:100%}button{padding:10px;font:inherit}output{display:block;padding:12px 0;font-variant-numeric:tabular-nums}</style>
<h1>Uploaded Phoenix 2 fire — exact timestamp pairs</h1>
<p>Reference starts at decoded frame 56: the later ship hit, not the already-burning explosion at the start of the clip. Every reference frame from that point has a corresponding Godot capture at the same relative presentation time. Timing alignment is verified; visual matching is still in progress. The fixture includes an approximate initial blue hit, a pink overlap at pair 18, and traveling twin shots at pairs 0, 17, 34 and 51. Ships, background, movement and the original weapon differ; this is not a gameplay replay.</p>
<button id="previous">Previous</button> <button id="play">Play</button> <button id="next">Next</button>
<input id="seek" type="range" min="0" value="0" aria-label="Paired frame"><output id="status"></output>
<div class="pair"><figure><figcaption>Uploaded reference</figcaption><img id="reference" alt="Reference frame"></figure><figure><figcaption>Current procedural fire</figcaption><img id="ours" alt="Godot frame at the same relative timestamp"></figure></div>
<script>
const pairs=DATA, el=id=>document.getElementById(id);let playing=false,start=0;
el('seek').max=pairs.length-1;
function show(i){el('seek').value=i;const p=pairs[i];el('reference').src=p.reference;el('ours').src=p.ours;el('status').textContent=`Pair ${i}/${pairs.length-1} · ${p.seconds.toFixed(4)} s since impact · source frame ${p.reference_frame} at ${p.source_seconds.toFixed(4)} s`;}
function stop(){playing=false;el('play').textContent='Play';}
function step(n){stop();show(Math.max(0,Math.min(pairs.length-1,Number(el('seek').value)+n)));}
el('previous').onclick=()=>step(-1);el('next').onclick=()=>step(1);el('seek').oninput=()=>{stop();show(Number(el('seek').value));};
el('play').onclick=()=>{if(playing){stop();return;}if(Number(el('seek').value)===pairs.length-1)show(0);playing=true;start=performance.now()-pairs[Number(el('seek').value)].seconds*1000;el('play').textContent='Pause';};
function tick(now){if(playing){let i=0;const t=(now-start)/1000;while(i+1<pairs.length&&pairs[i+1].seconds<=t)i++;show(i);if(i===pairs.length-1)stop();}requestAnimationFrame(tick);}requestAnimationFrame(tick);
document.addEventListener('keydown',e=>{if(e.target.tagName==='INPUT')return;if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();step(e.key==='ArrowLeft'?-1:1);}});show(0);
</script></html>'''.replace("DATA", data)
    (OUT / "review.html").write_text(page)
    print(f"Verified {len(pairs)} exact timestamp pairs; wrote {OUT / 'review.html'}")
    if args.video:
        build_video(pairs)


def build_video(pairs):
    import av
    from fractions import Fraction
    from PIL import Image, ImageDraw

    path = OUT / "comparison.mp4"
    with av.open(str(path), "w") as output:
        stream = output.add_stream("libx264", rate=60)
        stream.width, stream.height = 1178, 1312
        stream.pix_fmt = "yuv420p"
        stream.codec_context.time_base = Fraction(1, 600)
        stream.codec_context.max_b_frames = 0
        stream.options = {"crf": "21", "preset": "fast"}
        for pair in pairs:
            with Image.open(OUT / pair["ours"]) as image:
                own = image.convert("RGB")
            with Image.open(OUT / pair["reference"]) as image:
                ref = image.convert("RGB").resize((589, 1280))
            if own.size != (589, 1280):
                raise ValueError("Expected the reference-sized Godot capture")
            canvas = Image.new("RGB", (1178, 1312), (14, 21, 30))
            canvas.paste(ref, (0, 32))
            canvas.paste(own, (589, 32))
            draw = ImageDraw.Draw(canvas)
            draw.text((12, 9), f"Uploaded reference | +{pair['seconds']:.3f}s", fill="white")
            draw.text((601, 9), "Current game | visual matching in progress", fill="white")
            frame = av.VideoFrame.from_image(canvas)
            frame.pts = round(pair["seconds"] * 600)
            frame.time_base = Fraction(1, 600)
            for packet in stream.encode(frame):
                output.mux(packet)
        for packet in stream.encode():
            output.mux(packet)
    with av.open(str(path)) as check:
        times = [frame.time for frame in check.decode(video=0)]
    if len(times) != len(pairs) or any(abs(t - p["seconds"]) > 0.00001 for t, p in zip(times, pairs)):
        raise ValueError("Encoded video does not preserve the source timestamps")
    print(f"Verified {len(times)} native-timestamp video frames: {path}")


if __name__ == "__main__":
    main()
