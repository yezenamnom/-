#!/usr/bin/env python3
"""Local test server for device testing of the Vela browser.

Usage:  python3 serve.py [port]      (default 8765, binds 0.0.0.0)
Android emulator/device: `adb reverse tcp:8765 tcp:8765` then open
http://localhost:8765/ in the app. iOS simulator: http://localhost:8765/.

Everything here is original test content (generated media, our own pages).
"""
import http.server
import os
import sys
import urllib.parse

ROOT = os.path.dirname(os.path.abspath(__file__))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        if url.path == "/download/attachment":
            body = b"%PDF-1.4\n% Vela test file\n"
            name = q.get("name", ["report.pdf"])[0]
            self.send_response(200)
            self.send_header("Content-Type", "application/pdf")
            self.send_header("Content-Disposition", f'attachment; filename="{name}"')
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if url.path == "/download/big":
            size = 50 * 1024 * 1024
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Disposition", 'attachment; filename="big-test.bin"')
            self.send_header("Content-Length", str(size))
            self.end_headers()
            chunk = b"\0" * 65536
            try:
                for _ in range(size // len(chunk)):
                    self.wfile.write(chunk)
            except (BrokenPipeError, ConnectionResetError):
                pass  # client canceled: expected in the cancel test
            return
        if url.path == "/download/needs-cookie":
            ok = "vela_test=" in (self.headers.get("Cookie") or "")
            body = b"cookie ok\n" if ok else b"no cookie\n"
            self.send_response(200 if ok else 403)
            self.send_header("Content-Disposition", 'attachment; filename="cookie-check.txt"')
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        return super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Serving {ROOT} on http://0.0.0.0:{port}/")
    http.server.ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
