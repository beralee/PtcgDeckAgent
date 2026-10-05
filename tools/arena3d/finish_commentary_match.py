"""Finalize and verify the offline commentary match demonstration."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/commentary-match-20260929"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, encoding="utf-8")


def main():
    evidence = json.loads((OUT / "video-evidence.json").read_text(encoding="utf-8"))
    capture = json.loads((OUT / "capture-silent.capture.json").read_text(encoding="utf-8"))
    assert not evidence["preview"]
    assert evidence["report"]["complete"] and evidence["report"]["winner"] == 1
    assert evidence["paid_api_requests"] == 0 and len(evidence["chapters"]) == 10
    assert capture["frames"] == evidence["video_frames"]
    duration = capture["seconds"]
    assert 115 <= duration <= 135
    metadata = [";FFMETADATA1", "title=18.5 玛俐长毛巨魔 × 开发者多龙｜文字解说实战", "comment=真实对局关键回合回放；离线子 Agent 模拟解说；DeepSeek 调用 0 次。"]
    chapters = [{"start": 0, "title": "开场"}] + evidence["chapters"] + [{"start": duration - 6, "title": "对局总结"}]
    for index, chapter in enumerate(chapters):
        end = chapters[index + 1]["start"] if index + 1 < len(chapters) else duration
        metadata.extend(["[CHAPTER]", "TIMEBASE=1/1000", f"START={round(chapter['start']*1000)}", f"END={round(end*1000)}", f"title={chapter['title']}"])
    meta_path = OUT / "chapters.ffmeta"
    meta_path.write_text("\n".join(metadata) + "\n", encoding="utf-8")
    final = OUT / "PTCG-18.5-Marnie-vs-Developer-Dragapult-Commentary.mp4"
    run("ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-i", str(OUT / "capture-silent.mp4"),
        "-stream_loop", "-1", "-i", str(ROOT / "assets/audio/bgm/pokemon_sv_battle_gym_leader.mp3"),
        "-f", "ffmetadata", "-i", str(meta_path), "-map", "0:v:0", "-map", "1:a:0", "-map_metadata", "2", "-map_chapters", "2",
        "-vf", "scale=in_range=pc:out_range=tv,format=yuv420p", "-color_range", "tv",
        "-c:v", "libx264", "-crf", "19", "-preset", "fast", "-c:a", "aac", "-b:a", "160k", "-af", f"volume=0.11,afade=t=in:st=0:d=2,afade=t=out:st={duration-3}:d=3",
        "-t", str(duration), "-movflags", "+faststart", str(final))
    info = json.loads(run("ffprobe", "-v", "error", "-show_streams", "-show_format", "-show_chapters", "-of", "json", str(final)).stdout)
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert (video["width"], video["height"]) == (1600, 900)
    assert video["codec_name"] == "h264" and video["pix_fmt"] == "yuv420p"
    assert audio["codec_name"] == "aac" and audio["channels"] == 2
    assert abs(float(info["format"]["duration"]) - duration) < 0.1
    assert len(info["chapters"]) == 12
    decoded = run("ffmpeg", "-v", "error", "-i", str(final), "-f", "null", "-")
    assert not decoded.stderr.strip(), decoded.stderr
    for mark, timestamp in [("cover", 2), ("action", 69), ("closing", duration - 3)]:
        run("ffmpeg", "-y", "-v", "error", "-ss", str(timestamp), "-i", str(final), "-frames:v", "1", str(OUT / f"{mark}.jpg"))
    data = final.read_bytes()
    evidence["file"] = {"name": final.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest(), "md5": hashlib.md5(data).hexdigest(), "seconds": duration, "width": 1600, "height": 900, "full_decode_ok": True}
    (OUT / "video-evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "ffprobe.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(evidence["file"], ensure_ascii=False))


if __name__ == "__main__":
    main()
