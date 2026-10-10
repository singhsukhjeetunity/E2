"""Four trading EAs must gate entries and leave exits/recovery independent."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]

def read(p):
    return (ROOT/p).read_text()

class PortfolioGuardIntegration(unittest.TestCase):
    def test_gate_is_fail_closed_live_and_tester_only_bypass(self):
        gate=read("strategies/shared/PortfolioGate.mqh")
        self.assertIn("if(MQLInfoInteger(MQL_TESTER)!=0)return true;",gate)
        for key in ('"HB"','"READY"','"LOCK"','"FLOOR"','"DAY"','"RH"','"RM"'):
            self.assertIn(key,gate)
        self.assertIn("if(!E2PGFresh(",gate)
        self.assertIn("if(equity<=floor)",gate)
        self.assertIn('GlobalVariableSet(key+"LOCK",1.0)',gate)
        self.assertIn("GlobalVariablesFlush();",gate)
    def test_all_four_entry_calls_covered(self):
        paths=[
            "strategies/GoldSessionFade/include/execution/E2OrderExecutor.mqh",
            "strategies/CompressionBreakout/CompressionEngine.mqh",
            "strategies/EURJPYGotobi/include/Runtime.mqh",
            "strategies/NQOpeningRange/NQ_Opening_Range.mq5",
            "strategies/EURUSDTwoDayReversal/EURUSD_Two_Day_Reversal.mq5",
        ]
        for p in paths:
            s=read(p)
            self.assertIn('PortfolioGate.mqh',s,p)
            self.assertIn('E2PGCanEnter()',s,p)
            self.assertTrue(s.index('E2PGCanEnter()')<s.rfind('OrderSend(')
                            if 'OrderSend(' in s else True,p)
        gold=read(paths[0]);self.assertIn("if(!E2PGCanEnter())",gold)
        compression=read(paths[1])
        self.assertGreaterEqual(compression.count("if(!E2PGCanEnter())"),2)
        self.assertIn("ArrayResize(g_records,n)",compression)
        self.assertIn('if(!E2PGCanEnter())',read(paths[2]))
        self.assertIn('if(!E2PGCanEnter())',read(paths[3]))
    def test_flatten_account_wide_not_magic_filtered(self):
        guard=read("strategies/PortfolioGuard/E2_PortfolioGuard.mq5")
        self.assertIn("ACCOUNT_EQUITY",guard)
        self.assertIn("PositionClose(ticket)",guard)
        self.assertIn("OrderDelete(order)",guard)
        self.assertIn("GlobalVariablesFlush()",guard)
        self.assertIn("if(day!=pg_day)",guard)
        self.assertIn("EventSetTimer(1)",guard)
        self.assertIn("InpCloseAllOnLimit=true",guard)
        self.assertNotIn("POSITION_MAGIC",guard)
        self.assertNotIn("ORDER_MAGIC",guard)
    def test_initial_reference_is_fail_closed(self):
        guard=read("strategies/PortfolioGuard/E2_PortfolioGuard.mq5")
        self.assertIn("InpFirstDayReferenceEquity=0.0",guard)
        self.assertIn("No verified beginning-of-day reference",guard)
        self.assertIn("GlobalVariableGet(pg_key+\"READY\")<0.5",guard)
        self.assertIn('manual_first=!GlobalVariableCheck(pg_key+"DAY")',guard)
        self.assertIn("manual_first?InpFirstDayReferenceEquity:0.0",guard)
        self.assertIn("if(!PGSetDay(day,can_seed,manual_first?InpFirstDayReferenceEquity:0.0))",guard)

if __name__=="__main__":
    unittest.main()
