#!/usr/bin/env python3
"""
故障核心 (Glitch Core) 文档查看服务器

启动方式：
    python3 docs/_viewer/serve.py [port]

默认端口 8765，启动后会自动打开浏览器。
按 Ctrl+C 停止服务。
"""

import http.server
import socketserver
import webbrowser
import sys
import socket
from pathlib import Path

DEFAULT_PORT = 8765
DOCS_DIR = Path(__file__).resolve().parent.parent


class GlitchDocsHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(DOCS_DIR), **kwargs)

    def end_headers(self):
        # 禁用浏览器缓存——文档处于频繁迭代阶段，每次请求强制重新加载
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

    def do_GET(self):
        if self.path in ('/', ''):
            self.send_response(302)
            self.send_header('Location', '/_viewer/index.html')
            self.end_headers()
            return
        super().do_GET()

    def guess_type(self, path):
        # 客户端通过 fetch().text() 读取 .md，需要纯文本类型
        if path.endswith('.md'):
            return 'text/plain; charset=utf-8'
        if path.endswith('.svg'):
            return 'image/svg+xml; charset=utf-8'
        return super().guess_type(path)

    def log_message(self, format, *args):
        msg = format % args
        if '" 200' in msg and ('.css' in msg or '.js' in msg):
            return
        sys.stderr.write(f"  {self.log_date_time_string()}  {msg}\n")


def find_free_port(start_port):
    for port in range(start_port, start_port + 20):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(('', port))
                return port
            except OSError:
                continue
    raise RuntimeError(f"找不到可用端口 (从 {start_port} 起 20 个都被占用)")


def main():
    port = DEFAULT_PORT
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"❌ 无效端口: {sys.argv[1]}")
            sys.exit(1)

    try:
        port = find_free_port(port)
    except RuntimeError as e:
        print(f"❌ {e}")
        sys.exit(1)

    url = f"http://localhost:{port}/"

    print("=" * 60)
    print("  📘 故障核心 (Glitch Core) 文档服务")
    print("=" * 60)
    print()
    print(f"  服务地址: {url}")
    print(f"  文档根目录: {DOCS_DIR}")
    print()
    print("  自动打开浏览器中…")
    print("  按 Ctrl+C 停止服务")
    print()
    print("=" * 60)
    print()

    try:
        webbrowser.open(url)
    except Exception:
        pass

    try:
        with socketserver.TCPServer(("", port), GlitchDocsHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n  👋 服务已停止")
        sys.exit(0)
    except Exception as e:
        print(f"\n\n❌ 服务异常: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
