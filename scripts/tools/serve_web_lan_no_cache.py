#!/usr/bin/env python3
"""Serve a local Godot Web export over LAN without stale browser assets."""

from __future__ import annotations

import argparse
import ssl
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit, urlunsplit


class NoCacheRequestHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path: str) -> str:
        """Mirror the production /dist URL prefix onto the local export root."""
        parts = urlsplit(path)
        request_path = parts.path
        if request_path == "/dist":
            request_path = "/"
        elif request_path.startswith("/dist/"):
            request_path = request_path[len("/dist") :]
        local_path = urlunsplit(("", "", request_path, parts.query, parts.fragment))
        return super().translate_path(local_path)

    def end_headers(self) -> None:
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--directory", required=True)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8060)
    parser.add_argument("--certfile")
    parser.add_argument("--keyfile")
    args = parser.parse_args()

    handler = partial(NoCacheRequestHandler, directory=args.directory)
    server = ThreadingHTTPServer((args.bind, args.port), handler)
    scheme = "http"
    if args.certfile or args.keyfile:
        if not args.certfile or not args.keyfile:
            parser.error("--certfile and --keyfile must be supplied together")
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certfile=args.certfile, keyfile=args.keyfile)
        server.socket = context.wrap_socket(server.socket, server_side=True)
        scheme = "https"
    print(
        f"Serving {args.directory} on {scheme}://{args.bind}:{args.port} "
        "with Cache-Control: no-store",
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
