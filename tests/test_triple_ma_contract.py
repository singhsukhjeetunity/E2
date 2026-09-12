"""Validate the exact MQL CSV header against the existing journal adapter."""
import csv
import io
import re
import unittest
from pathlib import Path
from journal.model import parse_csv

SOURCE=Path(__file__).resolve().parents[1]/"research"/"TripleMA"/"TripleMA.mq5"


class TripleMAContractTests(unittest.TestCase):
    def test_csv_headers_and_bidirectional_reports(self):
        text=SOURCE.read_text()
        headers=[re.findall(r'"([^"]+)"',h) for h in re.findall(r'string header\[\]=\{([^}]+)\}',text)]
        self.assertEqual(len(headers),2)
        for header in headers:
            output=io.StringIO();writer=csv.DictWriter(output,header);writer.writeheader()
            is_trade="trade_id" in header
            for direction in ("LONG","SHORT"):
                row={field:"0" for field in header}
                row.update(schema_version="E2_JOURNAL_V1",run_id="research_run",config_hash="CONFIG",candidate_id=direction,
                           strategy="TRIPLE_MA",symbol="EURUSD",timeframe="PERIOD_M15",direction=direction)
                if is_trade:
                    row.update(trade_id=direction,fill_time="2022-01-03 12:15:00",exit_time="2022-01-03 13:00:00",
                               net_profit="98",actual_initial_cash_risk="100",trade_status="FINALIZED",gross_profit="100",
                               commission="-2",swap="0",fee="0",realized_r="0.98",integrity_flags="NONE")
                else:
                    row.update(signal_bar_time="2022-01-03 12:00:00",candidate_status="EXECUTED",candidate_reason="ENTRY_CONFIRMED")
                writer.writerow(row)
            parsed=parse_csv(output.getvalue().encode(),{"id":"research","kind":"Backtest"})
            self.assertEqual(parsed["errors"],[])
            self.assertEqual(len(parsed["rows"]),2)
            self.assertEqual(parsed["kind"],"trades" if is_trade else "signals")

    def test_production_input_isolation_and_tester_gate(self):
        text=SOURCE.read_text()
        self.assertNotIn('E2Config.mqh',text)
        init=text.split('int OnInit()',1)[1]
        self.assertIn('if(!MQLInfoInteger(MQL_TESTER))',init)
        self.assertLess(init.index('if(!MQLInfoInteger(MQL_TESTER))'),init.index('g_trade.SetExpertMagicNumber'))
        self.assertIn('g_trade.Buy(volume,_Symbol,entry,sl,tp,t.comment)',text)
        self.assertIn('g_trade.Sell(volume,_Symbol,entry,sl,tp,t.comment)',text)
        self.assertNotIn('CopyBuffer(g_fast,0,0,',text)
        self.assertNotIn('CopyBuffer(g_medium,0,0,',text)


if __name__=="__main__":unittest.main()
