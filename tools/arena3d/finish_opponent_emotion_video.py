"""Mux the fresh match recording, verify it, and bundle generated emotes."""
import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output/opponent-emotions-20260929"


def run(*args):
    return subprocess.run(args, check=True, capture_output=True, text=True, encoding="utf-8")


def main():
    evidence = json.loads((OUT / "video-evidence.json").read_text(encoding="utf-8"))
    capture = json.loads((OUT / "capture-silent.capture.json").read_text(encoding="utf-8"))
    assert not evidence["preview"] and not evidence["failures"]
    assert evidence["report"]["complete"] and not evidence["report"]["error"]
    assert evidence["report"]["seed"] == 20260930
    assert evidence["paid_api_requests"] == 0
    assert capture["frames"] == evidence["video_frames"]
    duration = capture["seconds"]
    assert 80 <= duration <= 300, duration
    metadata = [";FFMETADATA1", "title=18.5 玛俐长毛巨魔 × 开发者多龙｜心态表情陪练", "comment=新一局真实对战回放；离线模拟模型台词；12种生成表情；无付费DeepSeek调用。"]
    chapters = [{"start": 0, "title": "12种心态表情"}]
    for utterance in evidence["spoken"]:
        if utterance["video_time"] > chapters[-1]["start"] + 0.25:
            chapters.append({"start": utterance["video_time"], "title": f"{utterance['mood']} · 第{utterance['turn']}回合"})
    chapters.append({"start": duration - 5, "title": "对局结果"})
    for index, chapter in enumerate(chapters):
        end = chapters[index + 1]["start"] if index + 1 < len(chapters) else duration
        metadata += ["[CHAPTER]", "TIMEBASE=1/1000", f"START={round(chapter['start'] * 1000)}", f"END={round(end * 1000)}", f"title={chapter['title']}"]
    meta_path = OUT / "chapters.ffmeta"
    meta_path.write_text("\n".join(metadata) + "\n", encoding="utf-8")
    final = OUT / "PTCG-18.5-Opponent-Emotion-Match.mp4"
    run("ffmpeg", "-y", "-hide_banner", "-loglevel", "warning", "-i", str(OUT / "capture-silent.mp4"),
        "-stream_loop", "-1", "-i", str(ROOT / "assets/audio/bgm/pokemon_sv_battle_gym_leader.mp3"),
        "-f", "ffmetadata", "-i", str(meta_path), "-map", "0:v:0", "-map", "1:a:0", "-map_metadata", "2", "-map_chapters", "2",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-af", f"volume=0.10,afade=t=in:st=0:d=2,afade=t=out:st={duration-3}:d=3",
        "-t", str(duration), "-movflags", "+faststart", str(final))
    info = json.loads(run("ffprobe", "-v", "error", "-show_streams", "-show_format", "-show_chapters", "-of", "json", str(final)).stdout)
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert (video["width"], video["height"], video["pix_fmt"]) == (1600, 900, "yuv420p")
    assert video["codec_name"] == "h264" and audio["codec_name"] == "aac"
    assert abs(float(info["format"]["duration"]) - duration) < 0.12
    decoded = run("ffmpeg", "-v", "error", "-i", str(final), "-f", "null", "-")
    assert not decoded.stderr.strip(), decoded.stderr
    for mark, timestamp in [("cover", 2), ("gameplay", duration * .6), ("closing", duration - 2)]:
        run("ffmpeg", "-y", "-v", "error", "-ss", str(timestamp), "-i", str(final), "-frames:v", "1", str(OUT / f"{mark}.jpg"))
    data = final.read_bytes()
    evidence["file"] = {"name": final.name, "bytes": len(data), "md5": hashlib.md5(data).hexdigest(), "sha256": hashlib.sha256(data).hexdigest(), "seconds": duration, "width": 1600, "height": 900, "full_decode_ok": True}
    (OUT / "video-evidence.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "ffprobe.json").write_text(json.dumps(info, ensure_ascii=False, indent=2), encoding="utf-8")
    manifest = json.loads((ROOT / "assets/ui/opponent_emotions/manifest.json").read_text(encoding="utf-8"))
    bundle = OUT / "PTCG-Opponent-12-Emotions.zip"
    with zipfile.ZipFile(bundle, "w", zipfile.ZIP_DEFLATED) as archive:
        for name in manifest["order"]:
            archive.write(OUT / f"{name}.png", f"{name}.png")
        archive.write(ROOT / "assets/ui/opponent_emotions/portraits.png", "portraits.png")
        archive.write(ROOT / "assets/ui/opponent_emotions/manifest.json", "manifest.json")
        archive.writestr("README.txt", "原创陪练角色心态表情包\n12张256×256透明PNG，以及4列3行图集。\nmanifest.json列出顺序和心态。\n游戏实现见OpponentMood.gd；表情用于角色表达，不用于判断玩家的真实心理。\n".encode("utf-8"))
    with zipfile.ZipFile(bundle) as archive:
        assert archive.testzip() is None and len(archive.namelist()) == 15
    print(json.dumps({"video": evidence["file"], "emote_zip_bytes": bundle.stat().st_size}, ensure_ascii=False))


if __name__ == "__main__":
    main()
