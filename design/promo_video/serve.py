"""광고 모션그래픽 미리보기 서버.

저장소 루트를 정적으로 제공하고, 페이지가 녹화한 영상을 POST /save 로 받아
design/promo_video/<회차>/out/ 에 저장한다.
"""
import http.server
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8790


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self):
        match = re.fullmatch(r"/save/([\w-]+)/([\w.-]+\.(?:mp4|webm|png))", self.path)
        if not match:
            self.send_error(404)
            return
        session, name = match.groups()
        out_dir = ROOT / "design" / "promo_video" / session / "out"
        out_dir.mkdir(parents=True, exist_ok=True)
        length = int(self.headers.get("Content-Length", "0"))
        data = self.rfile.read(length)
        (out_dir / name).write_bytes(data)
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(f"saved {len(data)} bytes".encode())


if __name__ == "__main__":
    os.chdir(ROOT)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
