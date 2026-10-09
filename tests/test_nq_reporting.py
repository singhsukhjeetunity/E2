"""Guard System 5's published rules and journal export contract."""
from pathlib import Path
import re
import unittest

from journal.model import HEADERS

ROOT = Path(__file__).resolve().parents[1] / "strategies" / "NQOpeningRange"
EA = (ROOT / "NQ_Opening_Range.mq5").read_text()
REPORT = (ROOT / "NQReport.mqh").read_text()


class NQReportingTests(unittest.TestCase):
    def test_new_entries_are_long_only(self):
        entry = EA.split("void AttemptEntry(", 1)[1].split("void Run(", 1)[0]
        self.assertIn("if(tick.ask<=g_rangeHigh)return;", entry)
        self.assertIn("const ENUM_ORDER_TYPE side=ORDER_TYPE_BUY;", entry)
        self.assertIn("req.type=side", entry)
        self.assertNotIn("ORDER_TYPE_SELL", entry)
        self.assertNotIn("tick.bid<g_rangeLow", entry)
        self.assertIn("NQ_ORB_LONG_WEEKEND_FLAT_V4", REPORT)

    def test_friday_flat_uses_broker_sessions_and_blocks_late_entries(self):
        self.assertIn("SymbolInfoSessionTrade(_Symbol,FRIDAY,i,from,to)", EA)
        self.assertIn("cutoff=fridayStart+lastEnd-InpFridayCloseBufferMinutes*60", EA)
        self.assertIn("fridayDue||WeekendPassed(entryNY,ny)", EA)
        self.assertIn('"FRIDAY_FLAT":"WEEKEND_RECOVERY"', EA)
        self.assertIn("if(!FridayCloseAt(TimeCurrent(),fridayCutoff)||TimeCurrent()>=fridayCutoff)return;", EA)
        self.assertIn("if(!TradeSessionOpen(server)||server-g_lastCloseAttempt<60)return false;", EA)
        self.assertIn("IntegerToString(InpFridayCloseBufferMinutes)", REPORT)

    def test_filters_use_only_completed_bars(self):
        self.assertIn("CopyRates(_Symbol,PERIOD_D1,1,NQRangeATRDays+1,daily)", EA)
        self.assertIn("CopyRates(_Symbol,PERIOD_M5,1,1,previous)", EA)
        self.assertIn("previous[0].time+300!=currentBar", EA)
        self.assertIn("return closedPrice>g_rangeHigh;", EA)
        self.assertIn("g_rangeAllowed=g_rangeAtrRatio>=InpMinRangeATR&&g_rangeAtrRatio<=InpMaxRangeATR;", EA)

    def test_dashboard_only_has_operator_controls(self):
        names = set(re.findall(r"^input\s+(?:bool|int|double|ulong)\s+(\w+)", EA, re.M))
        self.assertEqual(names, {
            "InpEnableEntries", "InpExportCsv", "InpRiskMode", "InpFixedCashRisk",
            "InpBalanceRiskPercent", "InpMaxSpreadIndexPoints", "InpBrokerClockVerified",
            "InpServerUTCOffsetWinterHours", "InpServerUTCOffsetSummerHours", "InpBrokerDST",
            "InpUseRangeWidthFilter", "InpMinRangeATR", "InpMaxRangeATR",
            "InpRequireClosedM5Breakout", "InpFridayCloseBufferMinutes",
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
