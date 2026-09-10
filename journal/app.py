"""Loopback-only dashboard. No MT5 package, credentials, tokens to copy, or orders."""
import argparse
import base64
import csv
import io
import json
import os
import secrets
import sys
import threading
import webbrowser
import urllib.request
from http.cookies import SimpleCookie
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from .model import HEADERS, SCHEMA
from .store import Store, Watcher

ASSETS = Path(__file__).parent


def data_directory():
    return Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) / "E2Journal"


def make_server(store, port=8766):
    session = secrets.token_urlsafe(32)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, status, data, content_type="application/json; charset=utf-8", extra=None):
            if isinstance(data, (dict, list)):
                data = json.dumps(data, allow_nan=False).encode()
            elif isinstance(data, str):
                data = data.encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-E2-Application", "standalone-journal-v1")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
            for key, value in (extra or {}).items():
                self.send_header(key, value)
            self.end_headers()
            self.wfile.write(data)

        def authorised(self, api=True):
            host = self.headers.get("Host", "")
            if host not in (f"127.0.0.1:{self.server.server_port}", f"localhost:{self.server.server_port}"):
                self.reply(403, {"error": "Localhost only"}); return False
            if self.headers.get("Sec-Fetch-Site") == "cross-site":
                self.reply(403, {"error": "Open the dashboard directly on this computer"}); return False
            if self.command == "POST" and self.headers.get("Origin") != f"http://{host}":
                self.reply(403, {"error": "Same-origin request required"}); return False
            if api:
                cookie = SimpleCookie()
                try:
                    cookie.load(self.headers.get("Cookie", ""))
                    valid = "e2journal" in cookie and secrets.compare_digest(cookie["e2journal"].value, session)
                except Exception:
                    valid = False
                if not valid:
                    self.reply(401, {"error": "Reload the dashboard to reconnect"}); return False
            return True

        def do_GET(self):
            path = urlparse(self.path).path
            api = path.startswith("/api/")
            if not self.authorised(api):
                return
            try:
                if path == "/api/state":
                    args = {k: v[0] for k, v in parse_qs(urlparse(self.path).query).items() if k in ("account_id", "strategy", "config", "start", "end")}
                    return self.reply(200, store.snapshot(**args))
                if path == "/api/template":
                    buf = io.StringIO(); writer = csv.writer(buf)
                    writer.writerow(HEADERS + ["run_id"])
                    return self.reply(200, buf.getvalue(), "text/csv; charset=utf-8", {"Content-Disposition": 'attachment; filename="E2-Journal-template.csv"'})
                if path == "/api/backup":
                    backup = store.backup()
                    return self.reply(200, backup.read_bytes(), "application/octet-stream", {"Content-Disposition": f'attachment; filename="{backup.name}"'})
                if path == "/api/export":
                    account_id = parse_qs(urlparse(self.path).query).get("account_id", [""])[0]
                    store.account(account_id)
                    buf = io.StringIO(); writer = csv.writer(buf); writer.writerow(HEADERS + ["run_id"])
                    for t in store.rows("trades", account_id):
                        writer.writerow([SCHEMA, safe_csv(t["trade_id"]), safe_csv(t["strategy"]), safe_csv(t["config"]), safe_csv(t["symbol"]), t["direction"],
                                         t["opened"], t["closed"], t["net"], t["risk"], "FINALIZED", safe_csv(t["run_id"])])
                    return self.reply(200, buf.getvalue(), "text/csv; charset=utf-8", {"Content-Disposition": 'attachment; filename="E2-Journal-trades.csv"'})
                assets = {"/": ("index.html", "text/html; charset=utf-8"), "/app.js": ("app.js", "text/javascript; charset=utf-8"),
                          "/style.css": ("style.css", "text/css; charset=utf-8")}
                if path in assets:
                    name, kind = assets[path]
                    extra = {"Set-Cookie": f"e2journal={session}; Path=/; HttpOnly; SameSite=Strict"} if path == "/" else {}
                    return self.reply(200, (ASSETS / name).read_bytes(), kind, extra)
                self.reply(404, {"error": "Not found"})
            except (ValueError, OSError) as exc:
                self.reply(400, {"error": str(exc)})

        def do_POST(self):
            if not self.authorised():
                return
            try:
                if self.headers.get("Content-Type", "").split(";")[0] != "application/json":
                    raise ValueError("JSON required")
                size = int(self.headers.get("Content-Length", "0"))
                if size <= 0 or size > 180 * 1024 * 1024:
                    raise ValueError("Invalid request size")
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict):
                    raise ValueError("Invalid request")
                path = urlparse(self.path).path
                if path in ("/api/preview", "/api/import"):
                    content = base64.b64decode(data.get("content", ""), validate=True)
                    result = store.import_csv(data.get("account_id"), data.get("filename", "upload.csv"), content, path == "/api/import")
                elif path == "/api/account":
                    result = store.save_account(data)
                elif path == "/api/strategy":
                    result = store.save_note(data)
                elif path == "/api/trade":
                    result = store.manual_trade(data)
                elif path == "/api/flow":
                    result = store.save_flow(data)
                elif path == "/api/watch":
                    result = store.save_watch(data)
                elif path == "/api/watch-toggle":
                    with store.lock, store.connect() as db:
                        row = db.execute("SELECT data FROM watches WHERE id=?", (data.get("id"),)).fetchone()
                        if not row:
                            raise ValueError("Unknown folder")
                        result = json.loads(row[0]); result["enabled"] = bool(data.get("enabled"))
                        db.execute("UPDATE watches SET data=? WHERE id=?", (json.dumps(result), result["id"]))
                elif path == "/api/restore":
                    if data.get("confirm") != "RESTORE":
                        raise ValueError("Restore confirmation required")
                    result = store.restore(base64.b64decode(data.get("content", ""), validate=True))
                elif path == "/api/stop":
                    self.reply(200, {"stopped": True})
                    threading.Thread(target=self.server.shutdown, daemon=True).start()
                    return
                else:
                    return self.reply(404, {"error": "Not found"})
                self.reply(200, result)
            except (ValueError, KeyError, TypeError, OSError, csv.Error) as exc:
                self.reply(400, {"error": str(exc)})
            except Exception:
                import traceback
                traceback.print_exc()
                self.reply(500, {"error": "The operation failed. Your saved records remain on disk; check the application log."})

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


def safe_csv(value):
    value = str(value)
    # Neutralise spreadsheet formulas. The SQLite backup preserves the exact text.
    return "'" + value if value.startswith(("=", "+", "-", "@", "\t", "\r")) else value


def main():
    parser = argparse.ArgumentParser(description="E2 journal — analytics only")
    parser.add_argument("--data-dir", type=Path, default=data_directory())
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()
    store = Store(args.data_dir / "journal.sqlite3")
    try:
        server = make_server(store, args.port)
    except OSError:
        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{args.port}/", timeout=2) as response:
                existing = response.headers.get("X-E2-Application") == "standalone-journal-v1"
            if existing:
                if not args.no_browser:
                    webbrowser.open(f"http://127.0.0.1:{args.port}/")
                return
        except OSError:
            pass
        raise RuntimeError(f"Port {args.port} is already in use. If E2 Journal is already open, use that window; otherwise close the conflicting app.") from None
    watcher = Watcher(store)
    stop = threading.Event()
    def watch():
        while not stop.wait(15):
            try:
                watcher.scan()
            except Exception:
                import traceback
                traceback.print_exc()
    threading.Thread(target=watch, daemon=True).start()
    if not args.no_browser:
        webbrowser.open(f"http://127.0.0.1:{server.server_port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        stop.set(); server.server_close()


if __name__ == "__main__":
    main()
