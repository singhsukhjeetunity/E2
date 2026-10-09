"""Guard dashboard unit conversions, preserved baselines and Bund research defaults."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
def read(path):
    return (ROOT/path).read_text()
class DashboardMigration(unittest.TestCase):
    def test_hour_inputs_preserve_old_seconds_math(self):
        for name in ("EMAPullback/EMAEngine.mqh","CompressionBreakout/CompressionEngine.mqh"):
            s=read("strategies/"+name)
            self.assertIn("input int InpBrokerWinterUTCOffsetHours=0;",s)
            self.assertIn("#define InpBrokerWinterUtcOffsetSeconds (InpBrokerWinterUTCOffsetHours*3600)",s)
            self.assertNotRegex(s,r"(?m)^input int InpBrokerWinterUtcOffsetSeconds")
        g=read("strategies/GoldSessionFade/include/core/E2Config.mqh")
        self.assertIn("#define InpBrokerUtcOffsetSeconds (InpBrokerUTCOffsetHours*3600)",g)
        self.assertIn("input int InpBrokerUTCOffsetHours=0;",g)
        got=read("strategies/EURJPYGotobi/include/Runtime.mqh")
        self.assertIn("input int InpBrokerWinterUTCOffsetHours=2;",got)
        self.assertIn("InpBrokerWinterUTCMinutes=InpBrokerWinterUTCOffsetHours*60;",got)
        self.assertIn("InpBrokerWinterUTCOffsetHours=2",read("presets/EURJPYGotobi_50p_configurable.set"))
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
                     "strategies/BundDonchian/BundReport.mqh",
                     "strategies/EURJPYGotobi/include/Exports.mqh"):
            self.assertIn("_Trades_T.csv",read(path))
    def test_bund_uses_prior_closed_bars_and_risk(self):
        s=read("strategies/BundDonchian/Bund_Donchian_Breakout.mq5")
        for token in ("InpEntryChannelBars=20","InpExitChannelBars=10",
                      "InpATRPeriod=14","InpStopATR=2.0",
                      "CopyRates(_Symbol,PERIOD_H1,1,need,candles)",
                      "candles[0].close>entryHi","candles[0].close<entryLo",
                      "OrderCalcProfit(side,_Symbol,1.0,entry,stop,pnl)",
                      "InpEnableEntries=false"):
            self.assertIn(token,s)
if __name__=="__main__":
    unittest.main()
