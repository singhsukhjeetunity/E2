"""Strict CSV adapters and closed-trade analytics; Python standard library only."""
import csv
import hashlib
import io
import json
import math
from collections import defaultdict
from datetime import datetime

SCHEMA = "E2_JOURNAL_V1"
HEADERS = ["schema_version", "trade_id", "strategy", "config_hash", "symbol", "direction",
           "fill_time", "exit_time", "net_profit", "actual_initial_cash_risk", "trade_status"]


def number(value, name, optional=False):
    if optional and (value is None or str(value).strip() == ""):
        return None
    try:
        result = float(value)
    except (ValueError, TypeError):
        raise ValueError(f"{name}: enter a number using a decimal point") from None
    if not math.isfinite(result) or abs(result) > 1e15:
        raise ValueError(f"{name}: invalid or excessive number")
    return result


def label(value, name, maximum=180):
    result = str(value or "").strip()
    if not result or len(result) > maximum or any(ord(c) < 32 for c in result):
        raise ValueError(f"{name}: required, up to {maximum} characters")
    return result


def timestamp(value):
    value = str(value or "").strip().replace(".", "-", 2)
    try:
        date = datetime.fromisoformat(value)
    except ValueError:
        raise ValueError(f"Invalid date: {value}. Use YYYY-MM-DD HH:MM:SS") from None
    if date.tzinfo is not None:
        raise ValueError("Use one consistent, timezone-free reporting clock per dataset")
    return date.isoformat(sep=" ", timespec="seconds")


def key_for(account, row, identifier):
    # Backtest tickets are reused. Different runs MUST NOT be folded together.
    scope = row.get("run_id", "") if account["kind"] == "Backtest" else ""
    return hashlib.sha256(json.dumps([account["id"], scope, identifier]).encode()).hexdigest()


def normalize_trade(row, account):
    identifier = row.get("position_identifier") or row.get("trade_id")
    if str(identifier or "").strip() in ("", "0"):
        raise ValueError("A nonzero position_identifier or trade_id is required")
    identifier = label(identifier, "Trade ID")
    strategy = label(row.get("strategy"), "Strategy")
    opened, closed = timestamp(row.get("fill_time")), timestamp(row.get("exit_time"))
    if closed < opened:
        raise ValueError("Exit precedes entry")
    net = number(row.get("net_profit"), "Net profit")
    risk = number(row.get("actual_initial_cash_risk"), "Initial risk", True)
    if risk is not None and risk < 0:
        raise ValueError("Initial risk cannot be negative")
    if risk == 0:
        risk = None
    components = [row.get(k) for k in ("gross_profit", "commission", "swap", "fee")]
    if all(v not in (None, "") for v in components):
        if abs(sum(number(v, "P&L component") for v in components) - net) > .021:
            raise ValueError("Net profit does not reconcile with gross + commission + swap + fee")
    direction = str(row.get("direction", "")).upper()
    direction = {"BUY": "LONG", "SELL": "SHORT"}.get(direction, direction)
    if direction not in ("LONG", "SHORT"):
        raise ValueError("Direction must be LONG/SHORT or BUY/SELL")
    result = {"key": key_for(account, row, identifier), "account_id": account["id"],
              "trade_id": identifier, "strategy": strategy,
              "config": str(row.get("config_hash") or "unspecified")[:180],
              "run_id": str(row.get("run_id") or "")[:180],
              "symbol": label(row.get("symbol"), "Symbol", 80), "direction": direction,
              "opened": opened, "closed": closed, "net": net, "risk": risk,
              "r": net / risk if risk else None,
              "flags": str(row.get("integrity_flags") or "NONE")[:300]}
    # With rounded money fields, the broker's displayed R can differ slightly.
    if row.get("realized_r") not in (None, "") and risk:
        reported = number(row["realized_r"], "Reported R")
        if abs(reported - result["r"]) > max(.00002, .011 / risk):
            raise ValueError("Reported R does not reconcile with net profit / initial risk")
    return result


def decode_csv(data):
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16")
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252")


def parse_csv(data, account):
    if len(data) > 24 * 1024 * 1024:
        raise ValueError("CSV limit is 24 MB; split larger files")
    text = decode_csv(data)
    if "\x00" in text:
        raise ValueError("Unsupported encoding; export UTF-8 CSV or UTF-16 with a BOM")
    try:
        dialect = csv.Sniffer().sniff(text[:16000], delimiters=",;\t")
    except csv.Error:
        dialect = csv.excel
    reader = csv.DictReader(io.StringIO(text), dialect=dialect)
    headers = reader.fieldnames or []
    if len(headers) != len(set(headers)):
        raise ValueError("Duplicate column names")
    trade_required = {"trade_id", "strategy", "symbol", "direction", "fill_time", "exit_time", "net_profit"}
    signal_required = {"candidate_id", "candidate_status", "candidate_reason", "strategy", "symbol", "signal_bar_time"}
    kind = "trades" if trade_required <= set(headers) else "signals" if signal_required <= set(headers) else None
    if kind is None:
        raise ValueError("Unrecognised CSV. Use E2 _T.csv / _S.csv or the journal template; raw price data and MT5 deal exports are not trade reports.")
    rows, errors, skipped, flagged = [], [], 0, 0
    for line, row in enumerate(reader, 2):
        if line > 100002:
            raise ValueError("At most 100,000 rows per file")
        try:
            if None in row or any(value is None for value in row.values()):
                raise ValueError("Incomplete row or extra columns")
            schema = row.get("schema_version", "")
            if schema not in ("XAU_SF_REPORT_V1", "ADXBB_REPORT_V1", "LRB_REPORT_V1", SCHEMA):
                raise ValueError(f"Unsupported schema_version: {schema or '(missing)'}")
            if account["kind"] == "Backtest" and not row.get("run_id"):
                raise ValueError("Backtest rows require run_id; use a unique run label in the template")
            if kind == "trades":
                if row.get("trade_status", "") not in ("FINALIZED", "CLOSED"):
                    skipped += 1
                    continue
                record = normalize_trade(row, account)
                flagged += record["flags"] != "NONE"
            else:
                identifier = label(row["candidate_id"], "Candidate ID", 500)
                record = {"key": key_for(account, row, identifier), "account_id": account["id"],
                          "candidate_id": identifier, "strategy": label(row["strategy"], "Strategy"),
                          "config": str(row.get("config_hash") or "unspecified")[:180],
                          "run_id": str(row.get("run_id") or "")[:180],
                          "symbol": label(row["symbol"], "Symbol", 80),
                          "time": timestamp(row["signal_bar_time"]),
                          "status": label(row["candidate_status"], "Status"),
                          "reason": label(row["candidate_reason"], "Reason")}
            rows.append(record)
        except (ValueError, TypeError) as exc:
            errors.append(f"Row {line}: {exc}")
    return {"kind": kind, "rows": rows, "errors": errors[:30], "error_count": len(errors),
            "skipped": skipped, "flagged": flagged}


def same_record(a, b, kind):
    ignore = {"run_id"} if kind == "trades" else {"run_id"}
    # Recovery can legitimately record a new run/config. Financial identity must match;
    # a changed config remains a conflict so variants cannot silently collapse.
    return {k: v for k, v in a.items() if k not in ignore} == {k: v for k, v in b.items() if k not in ignore}


def metrics(trades):
    rows = sorted(trades, key=lambda t: (t["closed"], t["key"]))
    wins = sum(t["net"] > 0 for t in rows)
    positive = sum(max(0, t["net"]) for t in rows)
    negative = -sum(min(0, t["net"]) for t in rows)
    known = [t for t in rows if t["r"] is not None]
    running = peak = dd = running_r = peak_r = dd_r = 0.
    curve, groups = [], defaultdict(list)
    for t in rows:
        groups[t["closed"]].append(t)
    for time, closed in groups.items():
        running += sum(t["net"] for t in closed)
        peak = max(peak, running)
        dd = max(dd, peak - running)
        running_r += sum(t["r"] or 0 for t in closed)
        peak_r = max(peak_r, running_r)
        dd_r = max(dd_r, peak_r - running_r)
        curve.append({"time": time, "net": running, "dd": peak - running})
    streak = longest = 0
    for t in rows:
        streak = streak + 1 if t["net"] < 0 else 0
        longest = max(longest, streak)
    return {"trades": len(rows), "net": running, "win_rate": wins / len(rows) * 100 if rows else None,
            "profit_factor": positive / negative if negative else None, "no_losses": bool(rows) and not negative,
            "expectancy_r": sum(t["r"] for t in known) / len(known) if known else None,
            "r_count": len(known), "total_r": sum(t["r"] for t in known) if known else None,
            "max_dd": dd, "max_dd_r": dd_r if rows and len(known) == len(rows) else None,
            "losing_streak": longest, "curve": curve}


def period_metrics(trades, length):
    periods = defaultdict(list)
    for trade in trades:
        periods[trade["closed"][:length]].append(trade)
    return [{"period": k, **{key: value for key, value in metrics(v).items() if key != "curve"}}
            for k, v in sorted(periods.items())]
