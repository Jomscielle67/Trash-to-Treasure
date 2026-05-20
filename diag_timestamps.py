from services.firebase_service import db
from datetime import datetime

print('=== TRANSACTION TIMESTAMP DIAGNOSTIC ===')
docs = list(db.collection('transactions').order_by('timestamp', direction='DESCENDING').limit(10).stream())
print(f'Total docs fetched: {len(docs)}')
for doc in docs[:5]:
    d = doc.to_dict()
    ts = d.get('timestamp')
    t_type = d.get('type')
    t_status = d.get('status')
    t_points = d.get('points')
    print(f'  type={t_type}  status={t_status}  points={t_points}')
    print(f'  timestamp raw: {repr(ts)}')
    if ts is not None and hasattr(ts, 'astimezone'):
        local_ts = ts.astimezone().replace(tzinfo=None)
        print(f'  timestamp local: {local_ts}')
    print()

print(f'Today datetime.now(): {datetime.now()}')

# Count total deposits
all_docs = list(db.collection('transactions').stream())
deposit_count = sum(1 for d in all_docs if d.to_dict().get('type') == 'deposit')
redeem_count = sum(1 for d in all_docs if d.to_dict().get('type') == 'redeem')
print(f'Total transactions: {len(all_docs)}  deposits: {deposit_count}  redeems: {redeem_count}')
