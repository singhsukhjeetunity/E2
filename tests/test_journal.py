import base64
import csv
import http.client
import io
import json
import tempfile
import threading
import unittest
from pathlib import Path

from journal.app import make_server
from journal.model import HEADERS, SCHEMA, metrics, parse_csv
from journal.store import Store, Watcher


def report(rows=None, delimiter=",", encoding="utf-8"):
    rows = rows if rows is not None else [{}]
    text = io.StringIO(); writer = csv.DictWriter(text, HEADERS + ["run_id"], delimiter=delimiter)
    writer.writeheader()
    for update in rows:
        row = dict(zip(HEADERS, [SCHEMA, "10001", "XAU_SESSION_FADE", "HASH8", "XAUUSD", "LONG",
                                "2022-01-03 12:35:00", "2022-01-03 14:00:00", "150", "100", "FINALIZED"]))
        row["run_id"] = "RUN1"; row.update(update); writer.writerow(row)
    return text.getvalue().encode(encoding)


class JournalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.store = Store(self.root / "journal.sqlite3")
        self.account = self.store.save_account({"name": "Eval1", "kind": "Eval", "currency": "USD", "starting_balance": 200000})
        self.id = self.account["id"]

    def ingest(self, data=None, commit=True):
        return self.store.import_csv(self.id, "report.csv", data if data is not None else report(), commit)

    def test_preview_does_not_write(self):
        preview = self.ingest(commit=False)
        self.assertEqual(preview["new"], 1)
        self.assertFalse(preview["committed"])
        self.assertEqual(self.store.rows("trades"), [])

    def test_duplicate_across_renamed_files_and_live_restarts(self):
        self.ingest()
        result = self.ingest(report([{"run_id": "RUN2"}]))
        self.assertEqual(result["duplicates"], 1)
        self.assertEqual(len(self.store.rows("trades")), 1)

    def test_duplicate_in_one_file(self):
        result = self.ingest(report([{}, {}]))
        self.assertEqual((result["new"], result["duplicates"]), (1, 1))

    def test_conflict_atomic(self):
        self.ingest()
        result = self.ingest(report([{"trade_id": "10002"}, {"net_profit": "90"}]))
        self.assertFalse(result["committed"])
        self.assertEqual(len(self.store.rows("trades")), 1)

    def test_invalid_row_atomic(self):
        result = self.ingest(report([{}, {"trade_id": "10002", "net_profit": "NaN"}]))
        self.assertFalse(result["committed"])
        self.assertEqual(result["error_count"], 1)
        self.assertEqual(self.store.rows("trades"), [])

    def test_reversed_dates_rejected(self):
        self.assertEqual(self.ingest(report([{"exit_time": "2021-01-01 00:00:00"}]))["error_count"], 1)

    def test_account_isolation(self):
        self.ingest()
        other = self.store.save_account({"name": "Other", "kind": "Eval", "currency": "USD", "starting_balance": 10000})
        self.store.import_csv(other["id"], "same.csv", report(), True)
        self.assertEqual(len(self.store.rows("trades")), 2)

    def test_backtest_runs_not_combined(self):
        backtest = self.store.save_account({"name": "BT1", "kind": "Backtest", "currency": "USD", "starting_balance": 10000})
        self.store.import_csv(backtest["id"], "one.csv", report(), True)
        result = self.store.import_csv(backtest["id"], "two.csv", report([{"run_id": "RUN2"}]), True)
        self.assertFalse(result["committed"])
        self.assertIn("different run", result["errors"][0])

    def test_backtest_missing_run_blocked(self):
        account = {**self.account, "kind": "Backtest"}
        self.assertEqual(parse_csv(report([{"run_id": ""}]), account)["error_count"], 1)

    def test_bom_delimiters(self):
        for delimiter in (",", ";", "\t"):
            for encoding in ("utf-8-sig", "utf-16"):
                parsed = parse_csv(report(delimiter=delimiter, encoding=encoding), self.account)
                self.assertEqual(len(parsed["rows"]), 1)

    def test_non_final_and_unknown_risk(self):
        result = self.ingest(report([{"trade_status": "OPEN"}, {"trade_id": "10002", "actual_initial_cash_risk": ""}]))
        self.assertEqual(result["skipped"], 1)
        m = self.store.snapshot(self.id)["metrics"]
        self.assertEqual(m["trades"], 1)
        self.assertIsNone(m["expectancy_r"])
        self.assertIsNone(m["max_dd_r"])

    def test_net_metrics_and_initial_loss_drawdown(self):
        self.ingest(report([{"net_profit": "-100"}, {"trade_id": "2", "exit_time": "2022-01-04 14:00:00"},
                            {"trade_id": "3", "exit_time": "2022-01-05 14:00:00", "net_profit": "-100"}]))
        state = self.store.snapshot(self.id)
        m = state["metrics"]
        self.assertEqual((m["net"], m["max_dd"], m["max_dd_r"]), (-50, 100, 1))
        self.assertAlmostEqual(m["expectancy_r"], -1 / 6)
        self.assertAlmostEqual(m["profit_factor"], .75)
        self.assertEqual(state["years"][0]["trades"], 3)
        self.assertEqual(state["accounts"][0]["reconstructed_balance"], 199950)

    def test_simultaneous_exits_grouped_for_drawdown(self):
        self.ingest(report([{"net_profit": "-100"}, {"trade_id": "2", "net_profit": "150"}]))
        self.assertEqual(self.store.snapshot(self.id)["metrics"]["max_dd"], 0)

    def test_config_variants_separate_and_filters(self):
        self.ingest(report([{}, {"trade_id": "2", "config_hash": "OTHER", "exit_time": "2023-01-03 14:00:00"}]))
        self.assertEqual(len(self.store.snapshot(self.id)["systems"]), 2)
        self.assertEqual(self.store.snapshot(self.id, config="OTHER")["metrics"]["trades"], 1)
        self.assertEqual(self.store.snapshot(self.id, end="2022-12-31")["metrics"]["trades"], 1)

    def test_grade_allocation_not_hardcoded(self):
        result = self.store.save_account({**self.account, "allocations": {"A": 70, "B": 15, "C": 5}})
        self.assertEqual(sum(result["allocations"].values()), 90)
        with self.assertRaises(ValueError):
            self.store.save_account({**self.account, "allocations": {"A": 101}})

    def test_account_currency_and_type_immutable(self):
        with self.assertRaises(ValueError):
            self.store.save_account({**self.account, "currency": "GBP"})
        with self.assertRaises(ValueError):
            self.store.save_account({**self.account, "kind": "Backtest"})

    def test_cashflows_do_not_pollute_strategy_pnl(self):
        self.ingest()
        for kind, amount in [("Payout", 1000), ("Eval fee", 200), ("Withdrawal", 50)]:
            self.store.save_flow({"account_id": self.id, "kind": kind, "time": "2022-02-01 00:00:00", "amount": amount})
        state = self.store.snapshot(self.id)
        self.assertEqual(state["metrics"]["net"], 150)
        self.assertEqual(state["accounts"][0]["reconstructed_balance"], 200100)
        self.assertEqual(state["accounts"][0]["payouts"], 1000)

    def test_watch_requires_stable_file_and_deduplicates_restart(self):
        reports = self.root / "reports"; reports.mkdir()
        (reports / "E2_test_T.csv").write_bytes(report())
        self.store.save_watch({"account_id": self.id, "path": str(reports)})
        watcher = Watcher(self.store); watcher.scan()
        self.assertEqual(self.store.rows("trades"), [])
        watcher.scan(); self.assertEqual(len(self.store.rows("trades")), 1)
        other = Watcher(self.store); other.scan(); other.scan()
        self.assertEqual(len(self.store.rows("trades")), 1)

    def test_same_folder_cannot_bind_multiple_accounts(self):
        self.store.save_watch({"account_id": self.id, "path": str(self.root)})
        other = self.store.save_account({"name": "Other", "kind": "Demo", "currency": "USD", "starting_balance": 1})
        with self.assertRaises(ValueError):
            self.store.save_watch({"account_id": other["id"], "path": str(self.root)})

    def test_backup_restore_and_pause_watch(self):
        self.ingest(); self.store.save_watch({"account_id": self.id, "path": str(self.root)})
        backup = self.store.backup().read_bytes()
        self.ingest(report([{"trade_id": "2"}]))
        result = self.store.restore(backup)
        self.assertTrue(Path(result["safety_backup"]).is_file())
        self.assertEqual(len(self.store.rows("trades")), 1)
        self.assertFalse(self.store.rows("watches")[0]["enabled"])

    def test_reject_unknown_backup(self):
        with self.assertRaises(ValueError):
            self.store.restore(b"not a backup")

    def test_unknown_schema_and_prices_rejected(self):
        self.assertEqual(parse_csv(report([{"schema_version": "UNKNOWN"}]), self.account)["error_count"], 1)
        with self.assertRaises(ValueError):
            parse_csv(b"time,open,high,low,close\n20220101,1,2,1,2\n", self.account)

    def test_signal_import_never_counts_as_trade(self):
        data = ("schema_version,run_id,config_hash,candidate_id,strategy,symbol,signal_bar_time,candidate_status,candidate_reason\n"
                "XAU_SF_REPORT_V1,RUN1,HASH8,c1,XAU_SESSION_FADE,XAUUSD,2022-01-03 12:30:00,SAFETY_REJECTED,SPREAD\n").encode()
        self.ingest(data); duplicate = self.ingest(data)
        state = self.store.snapshot(self.id)
        self.assertEqual(state["metrics"]["trades"], 0)
        self.assertEqual(state["rejections"], [{"status": "SAFETY_REJECTED", "reason": "SPREAD", "count": 1}])
        self.assertEqual(duplicate["duplicates"], 1)

    def test_financial_reconciliation_rejects_bad_totals(self):
        source = next(csv.DictReader(io.StringIO(report().decode())))
        source.update(gross_profit="155", commission="-3", swap="-2", fee="0", realized_r="1.5")
        def encoded():
            output = io.StringIO(); writer=csv.DictWriter(output, list(source)); writer.writeheader();writer.writerow(source)
            return output.getvalue().encode()
        self.assertEqual(parse_csv(encoded(), self.account)["error_count"], 0)
        source["commission"]="-30"
        self.assertEqual(parse_csv(encoded(), self.account)["error_count"], 1)
        source["commission"]="-3";source["realized_r"]="2"
        self.assertEqual(parse_csv(encoded(), self.account)["error_count"], 1)

    def test_http_security_and_roundtrip(self):
        server = make_server(self.store, 0)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        self.addCleanup(server.server_close); self.addCleanup(server.shutdown)
        port = server.server_port
        def request(method, path, data=None, cookie=None, origin=None, host=None):
            connection = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
            headers = {"Content-Type": "application/json"}
            if cookie: headers["Cookie"] = cookie
            if origin: headers["Origin"] = origin
            if host: headers["Host"] = host
            connection.request(method, path, json.dumps(data) if data is not None else None, headers)
            response = connection.getresponse(); result=(response.status, dict(response.getheaders()), response.read());connection.close();return result
        self.assertEqual(request("GET", "/api/state")[0], 401)
        root = request("GET", "/"); self.assertEqual(root[0], 200)
        cookie = root[1]["Set-Cookie"].split(";")[0]
        self.assertEqual(request("GET", "/api/state", cookie=cookie)[0], 200)
        self.assertEqual(request("GET", "/api/state", cookie=cookie, host="evil.example")[0], 403)
        self.assertEqual(request("POST", "/api/trade", {}, cookie, "http://evil.example")[0], 403)
        payload={"account_id": self.id, "filename": "test.csv", "content": base64.b64encode(report()).decode()}
        result=request("POST", "/api/import", payload, cookie, f"http://127.0.0.1:{port}")
        self.assertTrue(json.loads(result[2])["committed"])
        self.assertEqual(request("GET", "/api/export?account_id="+self.id, cookie=cookie)[0], 200)
        self.assertEqual(request("POST", "/v1/proposals", {}, cookie, f"http://127.0.0.1:{port}")[0], 404)


if __name__ == "__main__":
    unittest.main()
