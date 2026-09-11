"""Offline Windows executable test; never imports or connects to MT5."""
import base64
import http.cookiejar
import json
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

with tempfile.TemporaryDirectory() as directory:
    process = subprocess.Popen([sys.argv[1], "--no-browser", "--data-dir", directory, "--port", "18866"])
    origin = "http://127.0.0.1:18866"
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def request(path, payload=None):
        request = urllib.request.Request(origin + path, data=json.dumps(payload).encode() if payload is not None else None,
                                         headers={"Content-Type": "application/json", "Origin": origin})
        return opener.open(request, timeout=3).read()
    try:
        deadline = time.monotonic() + 45
        while True:
            if process.poll() is not None:
                raise RuntimeError("Packaged app exited before serving")
            try:
                page = request("/")
                break
            except urllib.error.URLError:
                if time.monotonic() > deadline:
                    raise RuntimeError("Packaged journal did not start")
                time.sleep(.2)
        assert b"TRADING JOURNAL" in page
        assert b"'use strict'" in request("/app.js")
        assert b"--bg:#0b1018" in request("/style.css")
        account = json.loads(request("/api/account", {"name": "Smoke", "kind": "Demo", "currency": "USD", "starting_balance": 10000}))
        template = request("/api/template").decode()
        data = template + "E2_JOURNAL_V1,1,SMOKE,v1,EURUSD,LONG,2022-01-03 12:00:00,2022-01-03 13:00:00,15,10,FINALIZED,test\r\n"
        result = json.loads(request("/api/import", {"account_id": account["id"], "filename": "smoke.csv", "content": base64.b64encode(data.encode()).decode()}))
        assert result["committed"] and result["new"] == 1, result
        snapshot = json.loads(request("/api/state?account_id=" + account["id"]))
        assert snapshot["metrics"]["net"] == 15
        assert request("/api/backup").startswith(b"SQLite format 3")
        request("/api/stop", {})
        process.wait(timeout=10)
        assert process.returncode == 0
        print("Packaged journal: startup, assets, session, account, CSV import, metrics, backup and clean shutdown passed")
    finally:
        if process.poll() is None:
            process.terminate(); process.wait(timeout=10)
