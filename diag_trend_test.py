from services.firebase_service import db
from models.transaction import Transaction
from datetime import datetime, timedelta

all_docs = list(db.collection('transactions').stream())
all_transactions = [Transaction.from_dict(d.id, d.to_dict()) for d in all_docs]

def get_datetime(timestamp):
    if timestamp is None:
        return None
    if isinstance(timestamp, datetime):
        if timestamp.tzinfo is not None:
            return timestamp.astimezone().replace(tzinfo=None)
        return timestamp
    if hasattr(timestamp, 'timestamp'):
        return datetime.fromtimestamp(float(timestamp.timestamp()))
    return None

now = datetime.now()
today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
print(f"Today: {today_start.date()}, now: {now}")

# Simulate last 7 calendar days
weekly_trend_test = []
for i in range(6, -1, -1):
    day_start = today_start - timedelta(days=i)
    day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
    day_txns = [t for t in all_transactions
                if get_datetime(t.timestamp) and day_start <= get_datetime(t.timestamp) <= day_end]
    deposits = [t for t in day_txns if t.type == 'deposit']
    count = len(deposits) if deposits else len(day_txns)
    pts = sum(t.points for t in deposits) if deposits else sum(t.points for t in day_txns)
    weekly_trend_test.append({'date': day_start.strftime('%a %d'), 'bottles': count, 'points': pts})

print("Last 7 calendar days:", weekly_trend_test)

# Fallback
all_zero = all(d['bottles'] == 0 and d['points'] == 0 for d in weekly_trend_test)
print(f"All zero: {all_zero}")
if all_zero:
    tx_times = [get_datetime(t.timestamp) for t in all_transactions]
    tx_times = [t for t in tx_times if t is not None]
    if tx_times:
        most_recent = max(tx_times).replace(hour=0, minute=0, second=0, microsecond=0)
        print(f"Fallback window ending: {most_recent.date()}")
        fallback = []
        for i in range(6, -1, -1):
            day_start = most_recent - timedelta(days=i)
            day_end = day_start.replace(hour=23, minute=59, second=59, microsecond=999999)
            day_txns = [t for t in all_transactions
                        if get_datetime(t.timestamp) and day_start <= get_datetime(t.timestamp) <= day_end]
            deposits = [t for t in day_txns if t.type == 'deposit']
            count = len(deposits) if deposits else len(day_txns)
            pts = sum(t.points for t in deposits) if deposits else sum(t.points for t in day_txns)
            fallback.append({'date': day_start.strftime('%a %d'), 'bottles': count, 'points': pts})
        print("Fallback trend:", fallback)
