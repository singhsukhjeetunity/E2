"""Analyze one EMA pullback tester run. Python 3.10+, standard library only."""
import argparse
import csv
import datetime as dt
import json
import math
import statistics
from collections import defaultdict

NAMES = ("NP_EMA_M30_LONG",)
UTC = dt.timezone.utc

def stamp(text):
    return dt.datetime.fromisoformat(text).replace(tzinfo=UTC)

def read_csv(path):
    with open(path, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))

def drawdown(events):
    """Aggregate simultaneous settlements; start the high-water mark at zero."""
    buckets = defaultdict(float)
    for when, value in events:
        buckets[when] += value
    peak = total = worst = 0.0
    for when in sorted(buckets):
        total += buckets[when]
        peak = max(peak, total)
        worst = max(worst, peak - total)
    return worst

def longest_loss(trades):
    run = worst = 0
    for t in sorted(trades, key=lambda t: (t["exit_msc"], t["trade_id"])):
        run = run + 1 if t["r"] < 0 else 0
        worst = max(worst, run)
    return worst

def load_trades(rows, start, end):
    if not rows:
        raise ValueError("Empty trade ledger; no trade statistics available.")
    runs = {t["run_id"] for t in rows}
    configs = {t["config_hash"] for t in rows}
    if len(runs) != 1 or len(configs) != 1:
        raise ValueError("Use one run, not ledgers from different tester runs.")
    ids, out = set(), []
    for t in rows:
        if t["trade_id"] in ids:
            raise ValueError("Duplicate trade_id; import one ledger only.")
        ids.add(t["trade_id"])
        if t["trade_status"] != "FINALIZED" or t["integrity_flags"]:
            raise ValueError("Run contains unfinalized or integrity-flagged trades; inspect it before reporting.")
        if t["strategy"] not in NAMES:
            raise ValueError("Unexpected strategy.")
        risk, net = float(t["actual_initial_cash_risk"]), float(t["net_profit"])
        if not math.isfinite(risk) or not math.isfinite(net) or risk <= 0:
            raise ValueError("Invalid risk or PnL.")
        item = dict(t, entry_msc=int(t["entry_msc"]), exit_msc=int(t["exit_msc"]), r=net/risk, cash=net)
        if item["entry_msc"] > item["exit_msc"]:
            raise ValueError("Exit precedes entry.")
        item["date"] = dt.datetime.fromtimestamp(item["exit_msc"]/1000, UTC).date()
        entry_date = dt.datetime.fromtimestamp(item["entry_msc"]/1000, UTC).date()
        if not (start <= entry_date <= item["date"] < end):
            raise ValueError("Supplied test dates do not enclose every trade.")
        out.append(item)
    for name in NAMES:
        previous = None
        for t in sorted((t for t in out if t["strategy"] == name), key=lambda t: t["entry_msc"]):
            if previous and t["entry_msc"] < previous["exit_msc"]:
                raise ValueError("Overlapping positions within one strategy.")
            previous = t
    return out, next(iter(runs))

def summarize(trades, start, end):
    years = list(range(start.year, (end-dt.timedelta(days=1)).year+1))
    yearly = {str(y): sum(t["r"] for t in trades if t["date"].year == y) for y in years}
    ties = defaultdict(list)
    for t in trades:
        ties[t["exit_msc"]].append(t["r"])
    mixed_ties = sum(any(r<0 for r in v) and any(r>=0 for r in v) for v in ties.values())
    return dict(trades=len(trades),
                win_rate_pct=100*sum(t["r"]>0 for t in trades)/len(trades) if trades else None,
                net_r=sum(t["r"] for t in trades),
                expectancy_r=statistics.mean(t["r"] for t in trades) if trades else None,
                closed_drawdown_r=drawdown((t["exit_msc"], t["r"]) for t in trades),
                closed_drawdown_cash=drawdown((t["exit_msc"], t["cash"]) for t in trades),
                longest_losing_streak=longest_loss(trades),
                mixed_result_same_millisecond_groups=mixed_ties,
                yearly_r=yearly, median_calendar_year_r=statistics.median(yearly.values()),
                trades_per_365_25_days=len(trades)*365.25/(end-start).days)

def analyze(rows, start, end, equity=None):
    if end <= start:
        raise ValueError("End must be after start (exclusive).")
    trades, run = load_trades(rows, start, end)
    if any(t["date"].weekday()>=5 for t in trades):
        raise ValueError("Weekend exit: investigate session-close execution.")
    report = dict(run_id=run, start=str(start), end_exclusive=str(end),
                  assumptions=["R = actual initial cash risk, not account percent.",
                    "Closed drawdown excludes floating losses.",
                    "Losing streak breaks at breakeven.",
                    "Yearly figures include partial years where supplied.",
                    "This report does not establish out-of-sample profitability."],
                  ema=summarize(trades,start,end))
    if equity is not None:
        if not equity or any(t["run_id"] != run for t in equity):
            raise ValueError("Missing equity rows or mismatched run.")
        if any(t["run_failed"].lower() not in ("0","false") for t in equity):
            raise ValueError("EA marked the run failed.")
        dates = [stamp(t["time_utc"]) for t in equity]
        if any(y<=x for x,y in zip(dates,dates[1:])):
            raise ValueError("Equity timestamps are not strictly increasing.")
        eq_metrics = {}
        for key in ("equity_r","equity_cash"):
            vals = [0.0]+[float(t[key]) for t in equity]
            if not all(math.isfinite(v) for v in vals):
                raise ValueError("Nonfinite equity value.")
            peak = worst = 0.0
            for v in vals:
                peak=max(peak,v);worst=max(worst,peak-v)
            eq_metrics[key+"_sampled_drawdown"] = worst
        report["equity"] = dict(eq_metrics, observations=len(equity),
                                first_utc=str(dates[0]),last_utc=str(dates[-1]),
                                note="Approximately minute-sampled floating drawdown; intraminute extremes can be larger.")
    else:
        report["assumptions"].append("No equity file supplied: run_failed status and floating drawdown unverified.")
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trades", help="One E2_Trades_T.csv from an EMA run")
    parser.add_argument("--equity", help="Matching *_E.csv")
    parser.add_argument("--start", required=True, type=dt.date.fromisoformat)
    parser.add_argument("--end", required=True, type=dt.date.fromisoformat, help="Exclusive tester end date")
    args=parser.parse_args()
    try:
        report=analyze(read_csv(args.trades),args.start,args.end,read_csv(args.equity) if args.equity else None)
    except (ValueError, KeyError) as exc:
        parser.error(str(exc))
    print(json.dumps(report,indent=2,allow_nan=False))

if __name__ == "__main__":
    main()
