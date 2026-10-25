import json,time
from pathlib import Path
import numpy as np
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--paths',default=str(Path(__file__).with_name('trade_paths.csv')))
parser.add_argument('--output',default='results.json')
args=parser.parse_args()
if args.paths.endswith('.npz'):
 p=np.load(args.paths)
else:
 a=np.genfromtxt(args.paths,delimiter=',',names=True);p={k:a[k] for k in a.dtype.names}
N=100000;H=213
risks=np.array([.0025,.0035,.005,.006,.0075,.01])

def draw_indices(pool,block,seed,h=H):
 rng=np.random.default_rng(seed);v=rng.integers(0,len(pool),size=N);out=np.empty((h,N),dtype=np.uint16)
 for j in range(h):
  if j:
   restart=rng.random(N)<1/block;v=(v+1)%len(pool);v[restart]=rng.integers(0,len(pool),size=int(restart.sum()))
  out[j]=pool[v]
 return out

def simulate(indices,f,extra_fee=False,fixed=False):
 f=np.atleast_1d(f)[:,None];bal=np.ones((len(f),N));peak=bal.copy();dd=np.zeros_like(bal)
 fee=p['fee7'] if extra_fee else np.zeros(len(p['ret']))
 for idx in indices:
  scale=f if fixed else f*bal
  low=bal+scale*(p['lo'][idx]-fee[idx]);up=bal+scale*np.maximum(0,p['hi'][idx]-fee[idx])
  dd=np.maximum(dd,1-low/peak)
  # Conservative within-trade bound: actual high denominator >= entry balance.
  dd=np.maximum(dd,scale*(p['inner'][idx]+fee[idx])/bal)
  peak=np.maximum(peak,up)
  bal=bal+scale*(p['ret'][idx]-fee[idx]);peak=np.maximum(peak,bal)
 return {'q99':np.quantile(dd,.99,axis=1).tolist(),'median_dd':np.median(dd,axis=1).tolist(),'median_return':np.median(bal-1,axis=1).tolist(),'p_loss':np.mean(bal<1,axis=1).tolist()}

cases=[('full_block5',np.arange(len(p['ret'])),5,False),('full_block10',np.arange(len(p['ret'])),10,False),('full_block20',np.arange(len(p['ret'])),20,False),('recent_2023_2025',np.flatnonzero(p['year']>=2023),10,False),('recent_2024_2025',np.flatnonzero(p['year']>=2024),10,False),('full_extra7',np.arange(len(p['ret'])),10,True),('recent_2024_2025_extra7',np.flatnonzero(p['year']>=2024),10,True)]
results={}
for j,(name,pool,block,fee) in enumerate(cases):
 start=time.time();idx=draw_indices(pool,block,271828+j)
 x=simulate(idx,risks,fee);guess=.01*.10/x['q99'][-1]
 for _ in range(3):
  q=simulate(idx,[guess],fee)['q99'][0];guess*=.10/q
 check=simulate(idx,[guess],fee)
 x.update(risks=risks.tolist(),cap=guess,at_cap=check,seconds=time.time()-start)
 results[name]=x;print(name,json.dumps(x),flush=True)
 Path(args.output).write_text(json.dumps(results,indent=2))
# Report short/long horizon sensitivity for full block10 at final primary cap.
cap=min(results[k]['cap'] for k in ['full_block5','full_block10','full_block20'])
for years,h in [(1,71),(3,213),(10,709)]:
 idx=draw_indices(np.arange(len(p['ret'])),10,314159+years,h)
 x=simulate(idx,[cap]);results['horizon_'+str(years)]={'risk':cap,**x};print('horizon',years,json.dumps(x),flush=True)
idx=draw_indices(np.arange(len(p['ret'])),10,271829)
x=simulate(idx,risks,fixed=True);results['fixed_cash_full_block10']={'risks':risks.tolist(),**x};print('fixedcash',json.dumps(x),flush=True)
Path(args.output).write_text(json.dumps(results,indent=2))

checks={}
for name,pool,block,fee in [('full',np.arange(709),5,False),('recent',np.flatnonzero(p['year']>=2024),10,False),('recent_cost',np.flatnonzero(p['year']>=2024),10,True)]:
 for horizon in [213,709]:
  idx=draw_indices(pool,block,8675309,horizon)
  out=simulate(idx,[.004,.005,.0075],fee)
  checks[name+'_'+str(horizon)]={'risks':[.004,.005,.0075],**out}
  print(name,horizon,json.dumps(out),flush=True)
results['recommended_checks']=checks

idx=draw_indices(np.flatnonzero(p['year']>=2024),10,8675309,709)
x=simulate(idx,[.002,.00225,.0023,.0024,.0025],True)
print(json.dumps(x),flush=True)
results['long_stress_checks']={'risks':[.002,.00225,.0023,.0024,.0025],**x}
Path(args.output).write_text(json.dumps(results,indent=2))
