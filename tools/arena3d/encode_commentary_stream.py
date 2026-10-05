"""Encode local Godot viewport JPEG frames without large intermediate movies."""
import argparse
import json
import socket
import struct
import subprocess
from pathlib import Path


def exact(conn, size):
    data = bytearray()
    while len(data) < size:
        part = conn.recv(size - len(data))
        if not part:
            if not data:
                return None
            raise RuntimeError("Truncated frame")
        data.extend(part)
    return data


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with socket.socket() as server:
        server.bind(("127.0.0.1", 18739))
        server.listen(1)
        server.settimeout(180)
        print("ENCODER_READY", flush=True)
        conn, _ = server.accept()
        log = args.output.with_suffix(".ffmpeg.log").open("w")
        process = subprocess.Popen(
            ["ffmpeg", "-y", "-hide_banner", "-loglevel", "warning",
             "-f", "image2pipe", "-framerate", "30", "-c:v", "mjpeg", "-i", "pipe:0",
             "-an", "-vf", "scale=in_range=pc:out_range=tv", "-color_range", "tv",
             "-c:v", "libx264", "-preset", "fast", "-crf", "19",
             "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(args.output)],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=log,
        )
        frames = 0
        try:
            with conn:
                conn.settimeout(120)
                while (header := exact(conn, 4)) is not None:
                    size, = struct.unpack(">I", header)
                    if not 100 < size < 8_000_000:
                        raise RuntimeError(f"Invalid frame length {size}")
                    data = exact(conn, size)
                    if data is None:
                        raise RuntimeError("Missing frame")
                    process.stdin.write(data)
                    frames += 1
        finally:
            process.stdin.close()
            code = process.wait(timeout=60)
            log.close()
        if code or frames == 0:
            raise RuntimeError(f"Encoder failed {code}, frames={frames}")
        args.output.with_suffix(".capture.json").write_text(
            json.dumps({"frames": frames, "fps": 30, "seconds": frames / 30}), encoding="utf-8"
        )
        print(f"ENCODED frames={frames} seconds={frames / 30}", flush=True)


if __name__ == "__main__":
    main()
