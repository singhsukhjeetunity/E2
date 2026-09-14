import datetime as dt
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from analyze_run import analyze, drawdown, corr, NAMES

START, END=dt.date(2024,1,1),dt.date(2025,1,1)
def row(i, day, result, strategy=0, hour=16):
    end=dt.datetime(2024,1,day,hour,tzinfo=dt.timezone.utc)
    return dict(run_id="test",config_hash="one",trade_id=str(i),strategy=NAMES[strategy],
                trade_status="FINALIZED",integrity_flags="",actual_initial_cash_risk="100",
                net_profit=str(result*100),entry_msc=str(int(end.timestamp()*1000)-3600000),
                exit_msc=str(int(end.timestamp()*1000)))
class AnalysisTests(unittest.TestCase):
    def test_initial_loss_and_ties(self):
        self.assertEqual(drawdown([(1,-2),(2,1),(3,-3)]),4)
        self.assertEqual(drawdown([(1,-2),(1,2)]),0)
    def test_correlations(self):
        self.assertAlmostEqual(corr([1,2,3],[3,2,1]),-1)
        self.assertIsNone(corr([1,1,1],[1,2,3]))
    def test_combined(self):
        r=analyze([row(1,2,-1),row(2,3,-1),row(3,4,2),
                   row(4,2,.5,1),row(5,3,.5,1)],START,END)
        self.assertEqual(r["nr4"]["longest_losing_streak"],2)
        self.assertEqual(r["combined"]["closed_drawdown_r"],1)
        self.assertEqual(r["combined"]["net_r"],1)
        self.assertEqual(r["overlapping_position_minutes"],120)
        self.assertEqual(r["combined"]["mixed_result_same_millisecond_groups"],2)
    def test_reject_duplicate_mixed_or_incomplete(self):
        good=row(1,2,-1)
        for bad in (good,dict(row(2,3,1),run_id="other"),
                    dict(row(2,3,1),trade_status="OPEN"),
                    dict(row(2,3,1),integrity_flags="END_OF_TEST_LIQUIDATION")):
            with self.assertRaises(ValueError):
                analyze([good,bad],START,END)
    def test_reject_overlap_same_strategy(self):
        with self.assertRaises(ValueError):
            analyze([row(1,2,-1),row(2,2,.5)],START,END)
    def test_equity_includes_floating_loss(self):
        e=[dict(run_id="test",time_utc="2024-01-02 15:00:00",run_failed="false",
                nr_equity_r="-2",ema_equity_r="0",combined_equity_r="-2",combined_equity_cash="-200")]
        r=analyze([row(1,2,1)],START,END,e)
        self.assertEqual(r["equity"]["combined_equity_r_sampled_drawdown"],2)
        e[0]["run_failed"]="true"
        with self.assertRaises(ValueError):analyze([row(1,2,1)],START,END,e)
if __name__=="__main__":unittest.main()
