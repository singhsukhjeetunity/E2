"""Guard System 5's published rules and journal export contract."""
from pathlib import Path
import re
import unittest

from journal.model import HEADERS

ROOT = Path(__file__).resolve().parents[1] / "strategies" / "NQOpeningRange"
EA = (ROOT / "NQ_Opening_Range.mq5").read_text()
REPORT = (ROOT / "NQReport.mqh").read_text()


class NQReportingTests(unittest.TestCase):
    def test_dashboard_only_has_operator_controls(self):
        names = set(re.findall(r"^input\s+(?:bool|int|double|ulong)\s+(\w+)", EA, re.M))
        self.assertEqual(names, {
            "InpEnableEntries", "InpExportCsv", "InpRiskMode", "InpFixedCashRisk",
            "InpBalanceRiskPercent", "InpMaxSpreadIndexPoints", "InpBrokerClockVerified",
            "InpServerUTCOffsetWinterHours", "InpServerUTCOffsetSummerHours", "InpBrokerDST",
        })
        for rule in ("InpStopIndexPoints=100.0", "InpTargetIndexPoints=200.0",
                     "InpMaxEntriesPerNYDay=2", "InpMaxLongSessions=5",
                     "InpRangeStartNYMinute=570", "InpRangeEndNYMinute=660",
                     "InpLastEntryNYMinute=925", "InpSessionCloseNYMinute=930"):
            self.assertIn(rule, EA)

    def test_trade_csv_contains_journal_and_financial_fields(self):
        header = re.search(r'FileWrite\(file,"schema_version"(.+?)\);', REPORT, re.S)
        self.assertIsNotNone(header)
        columns = ["schema_version"] + re.findall(r'"([a-z_]+)"', header.group(1))
        self.assertTrue(set(HEADERS).issubset(columns))
        self.assertTrue({"gross_profit", "commission", "swap", "fee", "run_id", "position_id"}.issubset(columns))
        self.assertIn("gross+commission+swap+fee", REPORT)
        self.assertIn("OrderCalcProfit(side,_Symbol,amount,price,fillStop,loss)", REPORT)
        self.assertIn("HistoryDealGetDouble(deal,DEAL_PRICE)", REPORT)
        self.assertIn("HistoryOrderGetDouble(order,ORDER_SL)", REPORT)


if __name__ == "__main__":
    unittest.main()
