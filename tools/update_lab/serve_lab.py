"""Private-LAN-only HTTP fixture for the separate Android Update Lab APK."""
import argparse
import ipaddress
import socket
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

INVALID = b"This is deliberately not an APK."

def serve(package: Path, host: str, port: int) -> None:
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            peer = ipaddress.ip_address(self.client_address[0])
            if not (peer.is_private or peer.is_loopback):
                self.send_error(403)
                return
            mode = self.path.lstrip("/")
            if mode not in ("good", "slow", "drop", "truncated", "corrupt", "invalid", "stall"):
                self.send_error(404)
                return
            total = len(INVALID) if mode == "invalid" else package.stat().st_size
            limit = total // 2 if mode in ("drop", "truncated") else total
            start = 0
            etag = '"%x-%x"' % (package.stat().st_size, package.stat().st_mtime_ns)
            # Real system resume tests require a stable validator and byte ranges.
            if mode in ("good", "slow") and self.headers.get("Range"):
                value = self.headers["Range"]
                if not value.startswith("bytes=") or not value.endswith("-") or not value[6:-1].isdigit():
                    self.send_error(416)
                    return
                start = int(value[6:-1])
                if start >= total:
                    self.send_error(416)
                    return
            self.send_response(206 if start else 200)
            if mode in ("good", "slow"):
                self.send_header("ETag", etag)
                self.send_header("Accept-Ranges", "bytes")
            if start:
                self.send_header("Content-Range", f"bytes {start}-{total - 1}/{total}")
                print(f"RESUME {mode} offset={start}", flush=True)
            self.send_header("Content-Length", str((limit if mode == "truncated" else total) - start))
            self.send_header("Content-Type", "application/vnd.android.package-archive")
            self.send_header("Connection", "close")
            self.end_headers()
            if mode == "stall":
                time.sleep(10)
                return
            try:
                if mode == "invalid":
                    self.wfile.write(INVALID)
                    self.wfile.flush()
                    time.sleep(.05)
                    return
                with package.open("rb") as source:
                    source.seek(start)
                    sent = start
                    while sent < limit:
                        block = source.read(min(65536, limit - sent))
                        if not block:
                            return
                        if mode == "corrupt" and sent == 0:
                            block = bytes([block[0] ^ 1]) + block[1:]
                        self.wfile.write(block)
                        self.wfile.flush()
                        sent += len(block)
                        time.sleep(0.12 if mode == "slow" else 0.01)
            except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError, TimeoutError):
                pass
        def log_message(self, fmt, *args):
            print(fmt % args, flush=True)
    server = ThreadingHTTPServer((host, port), Handler)
    server.daemon_threads = True
    addresses = sorted({address[4][0] for address in socket.getaddrinfo(socket.gethostname(), port, socket.AF_INET)})
    print("Local validation only. No production service is changed.", flush=True)
    for address in addresses:
        if ipaddress.ip_address(address).is_private:
            print(f"Phone and PC on same Wi-Fi: http://{address}:{port}", flush=True)
    print("Keep this window open. Ctrl+C to stop.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, default=Path(__file__).with_name("B-update-payload.apk"))
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=18761)
    args = parser.parse_args()
    if not args.package.is_file():
        parser.error("B-update-payload.apk is missing")
    serve(args.package.resolve(), args.host, args.port)
