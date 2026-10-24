"""Host wiring / recovery invariants alongside active production-overlay runtime tests."""
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[1]
class TrailingIntegration(unittest.TestCase):
    def text(self,path):return (ROOT/"strategies"/path).read_text()
    def test_five_hosts_have_full_lifecycle_and_owned_close(self):
        cases=[
            ("GoldSessionFade/XAU_Session_Fade.mq5","g_configuration.expert_magic_number"),
            ("CompressionBreakout/CompressionEngine.mqh","InpMagic"),
            ("EURJPYGotobi/include/Runtime.mqh","InpMagic"),
            ("NQOpeningRange/NQ_Opening_Range.mq5","InpMagic"),
            ("BTCMomentumPullback/BTCUSD_Momentum_Pullback.mq5","InpMagic"),
        ]
        for path,magic in cases:
            with self.subTest(path=path):
                s=self.text(path)
                self.assertIn("EMATrailing.mqh",s)
                self.assertIn("E2TrailInit("+magic+")",s)
                self.assertIn("E2TrailShutdown();",s)
                self.assertIn("E2TrailRun();",s)
                self.assertIn("bool E2TrailClose(const ulong ticket)",s)
    def test_recovery_keeps_original_risk_metadata(self):
        gold=self.text("GoldSessionFade/include/strategy/E2PositionRecovery.mqh")
        self.assertIn("E2TrailStopOK(recovered.direction==E2_DIRECTION_LONG?1:-1,recovered.submitted_stop,live_sl,tol)",gold)
        self.assertIn("recovered.original_r-MathAbs(recovered.fill_price-recovered.submitted_stop)",gold)
        compression=self.text("CompressionBreakout/CompressionEngine.mqh")
        self.assertIn("E2TrailStopOK(1,g_records[k].sl,PositionGetDouble(POSITION_SL),tol)",compression)
        self.assertIn("MathMax(g_records[k].sl,PositionGetDouble(POSITION_SL))",compression)
        self.assertIn("net/g_records[k].risk_cash",compression)
        self.assertIn("if(k<0||g_slots[0].pending)return",compression)
        gold_host=self.text("GoldSessionFade/XAU_Session_Fade.mq5")
        self.assertIn("if(g_entry_pending)return;\n   E2TrailRun();",gold_host)
    def test_exit_settings_are_identifiable_in_reports(self):
        for path in ("BTCMomentumPullback/MomentumReport.mqh","NQOpeningRange/NQReport.mqh",
                     "GoldSessionFade/include/reporting/E2TradeReporter.mqh","CompressionBreakout/CompressionEngine.mqh"):
            self.assertIn("E2TrailDigest()",self.text(path))
        self.assertIn('"InpTrailingEMAPeriod"',self.text("EURJPYGotobi/include/Exports.mqh"))
if __name__=="__main__":unittest.main()
