#!/usr/bin/env python3
"""Generate deterministic, entirely fictional ARGUS hackathon data.

No external APIs, scraping, Faker datasets, or real PII are used.
Default seed: 42. Output CSVs are UTF-8 with ISO-8601 timestamps and stable ordering.
"""
from __future__ import annotations
import argparse, csv, hashlib, random
from datetime import date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

SEED=42
AS_OF=date(2026,10,5)
PARTY_COUNT=90
ACCOUNT_COUNT=130
TXN_LIMIT=5000
STRUCTURING_COUNT=20
BENIGN_COUNT=12
CURRENCY='VRD'
STRUCTURING_THRESHOLD=Decimal('950000')

FIRST=['Aven','Bex','Cira','Dovan','Elin','Faro','Galen','Havi','Iven','Jora','Kelan','Luma','Miro','Nexa','Orin']
LAST=['Amberfield','Brightmere','Cedarwyn','Duskvale','Emberlake','Frostmere','Goldhaven','Highbrook','Ironvale','Juniper','Kindleford','Larkspur']
OCC=['Archivist','Ceramics Maker','Florist','Repair Technician','School Administrator','Software Tester','Textile Trader','Wholesale Merchant']
BRANCHES=[('BR-V01','NORTH'),('BR-V02','SOUTH'),('BR-V03','EAST'),('BR-V04','WEST')]
CHANNELS=['CARD','TRANSFER','MOBILE','CASH']

def money(x): return f'{Decimal(str(x)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)}'
def stable_token(prefix,s): return prefix+hashlib.sha256(s.encode()).hexdigest()[:12].upper()
def write_csv(path, cols, rows):
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=cols,lineterminator='\n'); w.writeheader(); w.writerows(rows)

def generate(out:Path, seed:int=SEED):
    rng=random.Random(seed); out.mkdir(parents=True,exist_ok=True)
    parties=[]
    for i in range(1,PARTY_COUNT+1):
        pid=f'PTY-{i:04d}'; fn=FIRST[(i*7+seed)%len(FIRST)]; ln=LAST[(i*11+seed)%len(LAST)]
        parties.append({'party_id':pid,'party_type':'INDIVIDUAL' if i%6 else 'BUSINESS','full_name':f'{fn} {ln}' if i%6 else f'{ln} {fn} Works','dob':(date(1964,1,1)+timedelta(days=(i*337)%14000)).isoformat() if i%6 else '', 'nationality':'VERDANA','occupation':OCC[i%len(OCC)],'is_pep':'FALSE','risk_rating':['LOW','LOW','MEDIUM'][i%3],'onboarded_at':(date(2018,1,1)+timedelta(days=(i*29)%2700)).isoformat(),'national_id_masked_source':stable_token('VID-',pid)[0:4]+'********'+stable_token('',pid)[-4:],'email':f'fictional.{i:04d}@example.invalid','phone':f'+999-000-{i:04d}'})
    accounts=[]
    for i in range(1,ACCOUNT_COUNT+1):
        opened=date(2019,1,1)+timedelta(days=(i*17)%2400)
        accounts.append({'account_id':f'ACC-{i:05d}','party_id':f'PTY-{((i-1)%PARTY_COUNT)+1:04d}','account_type':['SAVINGS','CURRENT','WALLET'][i%3],'currency':CURRENCY,'branch_code':BRANCHES[i%4][0],'region':BRANCHES[i%4][1],'opened_at':opened.isoformat(),'closed_at':'','status':'ACTIVE','dormancy_flag':'FALSE','last_activity_at':AS_OF.isoformat()})
    tx=[]; truth=[]; seq=1
    def add(a,ts,amount,direction,channel,typ,is_cash,narrative,cpa='EXT-VERDANA',cpn='Fictional Counterparty'):
        nonlocal seq
        tx.append({'txn_id':f'TXN-{seq:07d}','account_id':a,'txn_ts':ts.strftime('%Y-%m-%dT%H:%M:%S'),'amount':money(amount),'currency':CURRENCY,'direction':direction,'channel':channel,'txn_type':typ,'counterparty_account':cpa,'counterparty_name':cpn,'counterparty_country':'VD','mcc':'','device_id':f'DEV-{((seq-1)%60)+1:04d}','is_cash':'TRUE' if is_cash else 'FALSE','narrative':narrative}); seq+=1
    # Baseline boring activity.
    start=datetime(2026,4,1,8,0)
    for ai in range(1,ACCOUNT_COUNT+1):
        aid=f'ACC-{ai:05d}'
        for k in range(18):
            ts=start+timedelta(days=(ai*5+k*9)%170,hours=(ai+k)%10,minutes=(ai*13+k*7)%60)
            direction='CREDIT' if k%4==0 else 'DEBIT'; channel=CHANNELS[(ai+k)%3]
            amount=Decimal(500+rng.randint(0,14500))+Decimal(rng.randint(0,99))/100
            add(aid,ts,amount,direction,channel,'TRANSFER' if channel!='CARD' else 'PURCHASE',False,'Synthetic routine activity')
    # T1: exactly 20 cash credits per account, each below 50k and above the policy aggregate.
    for ai in range(1,STRUCTURING_COUNT+1):
        aid=f'ACC-{ai:05d}'; window=datetime(2026,9,3,9,0); cash_total=Decimal('0')
        for k in range(20):
            amt=Decimal(48000+rng.randint(0,1000)); cash_total+=amt
            add(aid,window+timedelta(days=k%27,hours=(k*3)%9,minutes=k),amt,'CREDIT','CASH','CASH_DEPOSIT',True,'Synthetic planted structuring cash credit')
        assert cash_total >= STRUCTURING_THRESHOLD
        truth.append({'entity_id':aid,'entity_type':'ACCOUNT','typology_code':'STRUCTURING','label':'PLANTED','injected_at':AS_OF.isoformat(),'window_start':'2026-09-03','window_end':'2026-10-01','notes':f'20 cash credits; cash_total={money(cash_total)}; all individual credits below VRD 50,000'})
    # T8: legitimate businesses with similar cash cadence, but KYC-consistent and below policy aggregate.
    for ai in range(31,31+BENIGN_COUNT):
        aid=f'ACC-{ai:05d}'; window=datetime(2026,9,4,10,0); total=Decimal('0')
        for k in range(16):
            amt=Decimal(41000+rng.randint(0,6500)); total+=amt
            add(aid,window+timedelta(days=k%26,hours=k%7),amt,'CREDIT','CASH','CASH_DEPOSIT',True,'Synthetic documented retail takings')
        truth.append({'entity_id':aid,'entity_type':'ACCOUNT','typology_code':'BENIGN_LOOKALIKE','label':'BENIGN','injected_at':AS_OF.isoformat(),'window_start':'2026-09-04','window_end':'2026-09-30','notes':f'Legitimate business cash turnover; aggregate={money(total)}; expected activity'})
    assert len(tx)<=TXN_LIMIT
    tx.sort(key=lambda r:(r['txn_ts'],r['txn_id']))
    # Reassign IDs after chronological sort for stable Snowflake loading.
    for i,r in enumerate(tx,1): r['txn_id']=f'TXN-{i:07d}'
    write_csv(out/'parties.csv',list(parties[0]),parties)
    write_csv(out/'accounts.csv',list(accounts[0]),accounts)
    write_csv(out/'transactions.csv',list(tx[0]),tx)
    write_csv(out/'ground_truth.csv',list(truth[0]),truth)
    return len(parties),len(accounts),len(tx),len(truth)

def main():
    p=argparse.ArgumentParser(); p.add_argument('--seed',type=int,default=SEED); p.add_argument('--output-dir',type=Path,default=Path(__file__).resolve().parents[1]/'data'/'generated'); a=p.parse_args()
    counts=generate(a.output_dir,a.seed); print(f'Generated parties={counts[0]} accounts={counts[1]} transactions={counts[2]} ground_truth={counts[3]} seed={a.seed}')
if __name__=='__main__': main()
