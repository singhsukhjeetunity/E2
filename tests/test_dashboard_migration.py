"""Guard dashboard unit conversions, preserved baselines and four-EA configuration defaults."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT/path).read_text()
class DashboardMigration(unittest.TestCase):
    def test_hour_inputs_preserve_old_seconds_math(self):
        for name in ("CompressionBreakout/CompressionEngine.mqh",):
            s=read("strategies/"+name)
            self.assertIn("input double InpServerUTCOffsetWinterHours=0.0;",s)
            self.assertIn("#define InpBrokerWinterUtcOffsetSeconds ((int)MathRound(InpServerUTCOffsetWinterHours*3600.0))",s)
            self.assertNotRegex(s,r"(?m)^input int InpBrokerWinterUtcOffsetSeconds")
        g=read("strategies/GoldSessionFade/include/core/E2Config.mqh")
        self.assertIn("#define InpBrokerUtcOffsetSeconds ((int)MathRound(InpBrokerUTCOffsetHours*3600.0))",g)
        self.assertIn("input double InpBrokerUTCOffsetHours=0.0;",g)
        got=read("strategies/EURJPYGotobi/include/Runtime.mqh")
        self.assertIn("input double InpServerUTCOffsetWinterHours=2.0;",got)
        self.assertIn("InpBrokerWinterUTCMinutes=(int)MathRound(InpServerUTCOffsetWinterHours*60.0);",got)
        self.assertFalse((ROOT/"presets").exists())
    def test_existing_strategy_baselines_unchanged(self):
        gold=read("strategies/GoldSessionFade/include/core/E2Config.mqh")
        for token in ("InpXauATRMultiplier=8.0","InpXauTargetR=1.5","InpOneTradePerDay=true"):
            self.assertIn(token,gold)
        compression=read("strategies/CompressionBreakout/CompressionEngine.mqh")
        for token in ("InpCompressionRatio=0.8","InpStopATR=3.0","InpTargetR=2.0"):
            self.assertIn(token,compression)
        got=read("strategies/EURJPYGotobi/EURJPY_Gotobi.mq5")
        self.assertIn("InpStopPips=50",got)
        self.assertIn("InpEntryUTCMinute=955",got)
        nq=read("strategies/NQOpeningRange/NQ_Opening_Range.mq5")
        self.assertIn("InpStopIndexPoints=100.0",nq)
        self.assertIn("InpTargetIndexPoints=200.0",nq)
    def test_journal_app_removed_csv_preserved(self):
        self.assertFalse((ROOT/"journal").exists())
        self.assertFalse((ROOT/"Open-E2-Journal.pyw").exists())
        for path in ("strategies/NQOpeningRange/NQReport.mqh",
                     "strategies/EURJPYGotobi/include/Exports.mqh"):
            self.assertIn("_Trades_T.csv",read(path))
    def test_only_four_eas(self):
        paths=list((ROOT/"strategies").rglob("*.mq5"))
        self.assertEqual(len(paths),4)
        self.assertFalse((ROOT/"strategies/EMAPullback").exists())
        self.assertFalse((ROOT/"strategies/BundDonchian").exists())
if __name__=="__main__":
    unittest.main()
