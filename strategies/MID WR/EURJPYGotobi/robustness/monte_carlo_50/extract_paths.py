import json,time
from pathlib import Path
import numpy as np,pandas as pd
import argparse
parser=argparse.ArgumentParser(description='Extract risk-normalized sampled trade excursions from the original exports.')
parser.add_argument('--trades',required=True)
parser.add_argument('--equity',required=True)
parser.add_argument('--output',default='paths.npz')
args=parser.parse_args()
t=pd.read_csv(args.trades)
risk=t.actual_initial_cash_risk.to_numpy();ret=t.net_profit.to_numpy()/risk
entry=pd.to_datetime(t.fill_time,utc=True).astype('int64').to_numpy();exit=pd.to_datetime(t.exit_time,utc=True).astype('int64').to_numpy()
assert np.all(entry[1:]>exit[:-1]) and t.trade_status.eq('FINALIZED').all()
base=100000+np.r_[0,np.cumsum(t.net_profit.to_numpy())[:-1]]
hi=np.zeros(len(t));lo=np.zeros(len(t));inner=np.zeros(len(t));samples=np.zeros(len(t),int)
for chunk in pd.read_csv(args.equity,usecols=['time_utc','equity'],chunksize=200000):
 stamp=pd.to_datetime(chunk.time_utc,utc=True).astype('int64').to_numpy();eq=chunk.equity.to_numpy();idx=np.searchsorted(entry,stamp,side='right')-1
 valid=idx>=0;valid[valid]&=stamp[valid]<=exit[idx[valid]]
 idx=idx[valid];eq=eq[valid]
 for k in np.unique(idx):
  v=(eq[idx==k]-base[k])/risk[k]
  peak=np.maximum.accumulate(np.r_[hi[k],v])[1:]
  hi[k]=max(hi[k],float(v.max()));lo[k]=min(lo[k],float(v.min()));inner[k]=max(inner[k],float((peak-v).max()));samples[k]+=len(v)
# Include authoritative settlement, even if completion falls between equity samples.
inner=np.maximum(inner,hi-ret);hi=np.maximum(hi,ret);lo=np.minimum(lo,ret)
assert np.all(samples>0) and np.all(hi>=ret) and np.all(lo<=ret)
year=pd.to_datetime(t.fill_time,utc=True).dt.year.to_numpy()
np.savez(args.output,ret=ret,hi=hi,lo=lo,inner=inner,year=year,fee7=7*t.volume.to_numpy()/risk,samples=samples)
print(json.dumps({'trades':len(t),'min_samples':int(samples.min()),'largest_MAE_R':float(-lo.min()),'worst_intratrade_DD_R':float(inner.max()),'sum_R':float(ret.sum())}),flush=True)
