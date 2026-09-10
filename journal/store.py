"""Durable local journal; imports are atomic and never overwrite trade evidence."""
import base64
import csv
import hashlib
import json
import re
import sqlite3
import threading
import uuid
from contextlib import closing, contextmanager
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from .model import label, metrics, normalize_trade, number, parse_csv, period_metrics, same_record, timestamp


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


class Store:
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.RLock()
        self.generation = 0
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS accounts (id TEXT PRIMARY KEY, data TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS trades (key TEXT PRIMARY KEY, account_id TEXT NOT NULL, data TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS trades_account ON trades(account_id);
                CREATE TABLE IF NOT EXISTS signals (key TEXT PRIMARY KEY, account_id TEXT NOT NULL, data TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS signals_account ON signals(account_id);
                CREATE TABLE IF NOT EXISTS imports (id INTEGER PRIMARY KEY, account_id TEXT NOT NULL, data TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS notes (id TEXT PRIMARY KEY, data TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS flows (id TEXT PRIMARY KEY, account_id TEXT NOT NULL, data TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS watches (id TEXT PRIMARY KEY, data TEXT NOT NULL);
            """)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=15)
        db.row_factory = sqlite3.Row
        try:
            with db:
                yield db
        finally:
            db.close()

    def rows(self, table, account_id=None):
        assert table in ("accounts", "trades", "signals", "imports", "notes", "flows", "watches")
        with self.connect() as db:
            sql = f"SELECT data FROM {table}"
            args = ()
            if account_id is not None:
                sql += " WHERE account_id=?"
                args = (account_id,)
            if table == "imports":
                sql += " ORDER BY id DESC LIMIT 100"
            return [json.loads(r[0]) for r in db.execute(sql, args)]

    def account(self, identifier):
        with self.connect() as db:
            row = db.execute("SELECT data FROM accounts WHERE id=?", (identifier,)).fetchone()
        if not row:
            raise ValueError("Select an account / dataset first")
        return json.loads(row[0])

    def save_account(self, data):
        identifier = str(data.get("id") or uuid.uuid4())
        if data.get("id"):
            old = self.account(identifier)
        else:
            old = None
        kind = data.get("kind")
        if kind not in ("Eval", "Funded", "Personal", "Demo", "Backtest"):
            raise ValueError("Choose an account type")
        currency = label(data.get("currency"), "Currency", 3).upper()
        if not re.fullmatch("[A-Z]{3}", currency):
            raise ValueError("Use a three-letter currency code")
        balance = number(data.get("starting_balance"), "Starting balance")
        budget = number(data.get("daily_budget", 0), "Daily allowance")
        allocation = {g: number(data.get("allocations", {}).get(g, 0), f"Grade {g}") for g in "ABC"}
        if balance < 0 or budget < 0 or any(v < 0 or v > 100 for v in allocation.values()) or sum(allocation.values()) > 100.000001:
            raise ValueError("Balances and budgets must be nonnegative; grade allocations must total at most 100%")
        result = {"id": identifier, "name": label(data.get("name"), "Account name"), "kind": kind,
                  "currency": currency, "starting_balance": balance, "daily_budget": budget,
                  "allocations": allocation, "clock": label(data.get("clock", "Broker report time"), "Reporting clock"),
                  "notes": str(data.get("notes", ""))[:2000]}
        if old and (old["kind"], old["currency"], old["clock"]) != (kind, currency, result["clock"]):
            raise ValueError("Account type, currency and reporting clock are fixed. Create a separate dataset instead")
        with self.lock, self.connect() as db:
            db.execute("INSERT OR REPLACE INTO accounts VALUES (?,?)", (identifier, json.dumps(result)))
        return result

    def save_note(self, data):
        strategy = label(data.get("strategy"), "Strategy")
        config = label(data.get("config", "unspecified"), "Config")
        grade = data.get("grade", "Ungraded")
        status = data.get("status", "Research")
        if grade not in ("A", "B", "C", "Ungraded") or status not in ("Research", "Testing", "Active", "Paused", "Retired"):
            raise ValueError("Invalid grade or journal status")
        risk = number(data.get("risk_percent"), "Risk %", True)
        if risk is not None and not 0 <= risk <= 100:
            raise ValueError("Risk % must be between 0 and 100")
        result = {"strategy": strategy, "config": config, "grade": grade, "status": status,
                  "risk_percent": risk, "notes": str(data.get("notes", ""))[:4000]}
        with self.lock, self.connect() as db:
            db.execute("INSERT OR REPLACE INTO notes VALUES (?,?)", (json.dumps([strategy, config]), json.dumps(result)))
        return result

    def save_flow(self, data):
        self.account(data.get("account_id"))
        amount = number(data.get("amount"), "Amount")
        kind = data.get("kind")
        if kind not in ("Deposit", "Withdrawal", "Payout", "Eval fee", "Other fee") or amount <= 0:
            raise ValueError("Choose a cash-flow type and a positive amount")
        result = {"id": str(uuid.uuid4()), "account_id": data["account_id"], "time": timestamp(data.get("time")),
                  "kind": kind, "amount": amount, "notes": str(data.get("notes", ""))[:1000]}
        with self.lock, self.connect() as db:
            db.execute("INSERT INTO flows VALUES (?,?,?)", (result["id"], result["account_id"], json.dumps(result)))
        return result

    def prepare(self, db, parsed):
        table = parsed["kind"]
        existing = {}
        new, duplicates, conflicts = [], 0, []
        for row in parsed["rows"]:
            key = row["key"]
            if key not in existing:
                found = db.execute(f"SELECT data FROM {table} WHERE key=?", (key,)).fetchone()
                existing[key] = json.loads(found[0]) if found else None
            previous = existing[key]
            if previous is None:
                new.append(row)
                existing[key] = row
            elif same_record(previous, row, table):
                duplicates += 1
            else:
                conflicts.append(row.get("trade_id", row.get("candidate_id")))
        return new, duplicates, conflicts

    def import_csv(self, account_id, filename, content, commit=False):
        account = self.account(account_id)
        parsed = parse_csv(content, account)
        with self.lock, self.connect() as db:
            new, duplicates, conflicts = self.prepare(db, parsed)
            result = {k: v for k, v in parsed.items() if k != "rows"}
            result.update({"filename": Path(filename).name[:250], "new": len(new), "duplicates": duplicates,
                           "conflicts": conflicts[:20], "conflict_count": len(conflicts), "sample": new[:5],
                           "runs": sorted({r["run_id"] for r in parsed["rows"]}),
                           "configs": sorted({r["config"] for r in parsed["rows"]}), "committed": False})
            # A backtest dataset represents ONE run: never sum optimized variants.
            if account["kind"] == "Backtest":
                runs = set(result["runs"])
                for table in ("trades", "signals"):
                    runs.update(json.loads(r[0])["run_id"] for r in db.execute(f"SELECT data FROM {table} WHERE account_id=?", (account_id,)))
                if len(runs) > 1:
                    result["errors"].append("This backtest dataset already contains a different run. Create a separate dataset for each test run.")
                    result["error_count"] += 1
            if commit and not result["error_count"] and not conflicts:
                for row in new:
                    db.execute(f"INSERT INTO {parsed['kind']} VALUES (?,?,?)", (row["key"], account_id, json.dumps(row)))
                result["committed"] = True
            if commit:
                audit = {k: v for k, v in result.items() if k != "sample"}
                audit.update({"time": now(), "sha256": hashlib.sha256(content).hexdigest(), "account_id": account_id})
                db.execute("INSERT INTO imports(account_id,data) VALUES (?,?)", (account_id, json.dumps(audit)))
            return result

    def manual_trade(self, data):
        account = self.account(data.get("account_id"))
        row = normalize_trade(data, account)
        if account["kind"] == "Backtest":
            raise ValueError("Use CSV imports with a run_id for backtests")
        with self.lock, self.connect() as db:
            new, duplicates, conflicts = self.prepare(db, {"kind": "trades", "rows": [row]})
            if conflicts:
                raise ValueError("That trade ID already exists with different values; nothing was overwritten")
            if new:
                db.execute("INSERT INTO trades VALUES (?,?,?)", (row["key"], account["id"], json.dumps(row)))
        return {"new": len(new), "duplicates": duplicates}

    def save_watch(self, data):
        account = self.account(data.get("account_id"))
        path = Path(str(data.get("path", ""))).expanduser()
        if not path.is_absolute() or not path.is_dir():
            raise ValueError("Choose an existing absolute folder path")
        path = path.resolve()
        pattern = str(data.get("pattern") or "E2_*_T.csv")
        if not pattern.lower().endswith(".csv") or any(c in pattern for c in "/\\:") or len(pattern) > 180:
            raise ValueError("Use a filename pattern such as E2_*_T.csv, without subfolders")
        # Never silently bind one report stream to several accounts.
        identifier = hashlib.sha256(str(path).casefold().encode()).hexdigest()
        for watch in self.rows("watches"):
            if watch["id"] == identifier and watch["account_id"] != account["id"]:
                raise ValueError("This folder is already assigned to another dataset. Use a separate folder per account")
        result = {"id": identifier, "account_id": account["id"], "path": str(path), "pattern": pattern,
                  "enabled": bool(data.get("enabled", True)), "status": "Waiting for two stable scans", "last_scan": None}
        with self.lock, self.connect() as db:
            db.execute("INSERT OR REPLACE INTO watches VALUES (?,?)", (identifier, json.dumps(result)))
        return result

    def snapshot(self, account_id=None, strategy=None, config=None, start=None, end=None):
        accounts = self.rows("accounts")
        if account_id:
            self.account(account_id)
        trades = self.rows("trades", account_id) if account_id else []
        if strategy:
            trades = [r for r in trades if r["strategy"] == strategy]
        if config:
            trades = [r for r in trades if r["config"] == config]
        if start:
            datetime.strptime(start, "%Y-%m-%d")
            trades = [r for r in trades if r["closed"][:10] >= start]
        if end:
            datetime.strptime(end, "%Y-%m-%d")
            trades = [r for r in trades if r["closed"][:10] <= end]
        grouped = {}
        for t in trades:
            grouped.setdefault((t["strategy"], t["config"]), []).append(t)
        notes = {(n["strategy"], n["config"]): n for n in self.rows("notes")}
        systems = [{"strategy": key[0], "config": key[1], "note": notes.get(key, {}),
                    **{k: v for k, v in metrics(value).items() if k != "curve"}} for key, value in sorted(grouped.items())]
        allnotes = self.rows("notes")
        # Show manually registered research systems even before the first trade.
        for note in allnotes:
            if (note["strategy"], note["config"]) not in grouped and not strategy and not config:
                systems.append({"strategy": note["strategy"], "config": note["config"], "note": note,
                                **{k: v for k, v in metrics([]).items() if k != "curve"}})
        account_cards = []
        for account in accounts:
            alltrades = self.rows("trades", account["id"])
            flows = self.rows("flows", account["id"])
            transfers = sum(f["amount"] * (1 if f["kind"] == "Deposit" else -1) for f in flows if f["kind"] in ("Deposit", "Withdrawal"))
            account_cards.append({**account, "net": sum(t["net"] for t in alltrades),
                                  "reconstructed_balance": account["starting_balance"] + transfers + sum(t["net"] for t in alltrades),
                                  "payouts": sum(f["amount"] for f in flows if f["kind"] == "Payout"),
                                  "fees": sum(f["amount"] for f in flows if f["kind"] in ("Eval fee", "Other fee"))})
        signals = self.rows("signals", account_id) if account_id else []
        reasons = Counter((s["status"], s["reason"]) for s in signals)
        return {"accounts": account_cards, "metrics": metrics(trades), "systems": systems,
                "trades": sorted(trades, key=lambda t: (t["closed"], t["key"]), reverse=True),
                "years": period_metrics(trades, 4), "months": period_metrics(trades, 7),
                "imports": self.rows("imports", account_id) if account_id else self.rows("imports"),
                "flows": self.rows("flows", account_id) if account_id else [],
                "watches": self.rows("watches"), "notes": allnotes,
                "rejections": [{"status": k[0], "reason": k[1], "count": v} for k, v in reasons.most_common()],
                "data_path": str(self.path), "time": now()}

    def backup(self):
        # SQLite's online backup API produces a consistent snapshot even during imports.
        target = self.path.parent / "backups" / ("journal-" + datetime.now().strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:8] + ".sqlite3")
        target.parent.mkdir(exist_ok=True)
        with self.lock, self.connect() as source, closing(sqlite3.connect(target)) as dest:
            source.backup(dest)
        return target

    def restore(self, content):
        # Only accept our own SQLite schema. No SQL supplied by the browser is executed.
        if len(content) > 128 * 1024 * 1024 or not content.startswith(b"SQLite format 3\x00"):
            raise ValueError("Choose an E2 journal .sqlite3 backup, at most 128 MB")
        temp = self.path.parent / ("restore-" + uuid.uuid4().hex + ".sqlite3")
        try:
            temp.write_bytes(content)
            with closing(sqlite3.connect(temp)) as source, self.connect() as current:
                if source.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
                    raise ValueError("Backup failed its integrity check")
                schema = lambda db: db.execute("SELECT type,name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").fetchall()
                if schema(source) != [tuple(r) for r in schema(current)]:
                    raise ValueError("This backup uses a different journal schema")
                for table in ("accounts", "trades", "signals", "imports", "notes", "flows", "watches"):
                    for (raw,) in source.execute(f"SELECT data FROM {table}"):
                        if not isinstance(json.loads(raw), dict):
                            raise ValueError("Invalid backup record")
                with self.lock:
                    safety = self.backup()
                    source.backup(current)
                    self.generation += 1
                    # Restoring never resumes automatic imports without review.
                    for row in current.execute("SELECT id,data FROM watches").fetchall():
                        watch = json.loads(row[1]); watch["enabled"] = False
                        watch["status"] = "Paused after restore; review account and folder before enabling"
                        current.execute("UPDATE watches SET data=? WHERE id=?", (json.dumps(watch), row[0]))
            return {"restored": True, "safety_backup": str(safety)}
        finally:
            temp.unlink(missing_ok=True)


class Watcher:
    def __init__(self, store):
        self.store, self.observed, self.processed = store, {}, {}
        self.generation = store.generation

    def scan(self):
        with self.store.lock:
            if self.generation != self.store.generation:
                self.observed.clear(); self.processed.clear()
                self.generation = self.store.generation
            self._scan()

    def _scan(self):
        for watch in self.store.rows("watches"):
            if not watch["enabled"]:
                continue
            count, problems = 0, []
            try:
                folder = Path(watch["path"])
                if not folder.is_dir():
                    raise ValueError("Folder is unavailable")
                for path in sorted(folder.glob(watch["pattern"])):
                    if not path.is_file() or path.is_symlink():
                        continue
                    stat = path.stat()
                    key = (watch["id"], str(path))
                    stamp = (stat.st_mtime_ns, stat.st_size)
                    if self.observed.get(key) != stamp:
                        self.observed[key] = stamp
                        continue
                    if self.processed.get(key) == stamp:
                        continue
                    if stat.st_size > 24 * 1024 * 1024:
                        raise ValueError(f"{path.name}: file exceeds 24 MB")
                    content = path.read_bytes()
                    after = path.stat()
                    if (after.st_mtime_ns, after.st_size) != stamp:
                        continue
                    result = self.store.import_csv(watch["account_id"], path.name, content, True)
                    self.processed[key] = stamp
                    if not result["committed"]:
                        problems.append(f"{path.name}: import blocked; review import history")
                    else:
                        count += result["new"]
                watch["status"] = "; ".join(problems) if problems else f"Scanned; {count} new rows this scan. See import history for earlier results."
            except (OSError, ValueError, csv.Error) as exc:
                watch["status"] = str(exc)[:600]
            watch["last_scan"] = now()
            with self.store.lock, self.store.connect() as db:
                # Do not re-enable a watch that the user paused during the scan.
                latest = db.execute("SELECT data FROM watches WHERE id=?", (watch["id"],)).fetchone()
                if latest:
                    current = json.loads(latest[0])
                    current.update({"status": watch["status"], "last_scan": watch["last_scan"]})
                    db.execute("UPDATE watches SET data=? WHERE id=?", (json.dumps(current), watch["id"]))
