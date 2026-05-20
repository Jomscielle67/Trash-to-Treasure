from services.firebase_service import db
from datetime import datetime, timezone

students = list(db.collection('students').stream())
print(f"Total students: {len(students)}")
for s in students[:3]:
    d = s.to_dict()
    keys_wanted = ['bottles', 'totalBottlesLifetime', 'lastUpdated', 'lastActivityAt', 'points', 'totalPointsEarned', 'fullName']
    info = {k: d.get(k) for k in keys_wanted}
    print(info)

# Sum up totals
total_bottles = sum((d.to_dict().get('totalBottlesLifetime') or 0) for d in students)
total_current = sum((d.to_dict().get('bottles') or 0) for d in students)
print(f"\nTotal lifetime bottles (sum): {total_bottles}")
print(f"Total current bottles (sum): {total_current}")

# Check lastUpdated dates
print("\nStudent lastUpdated dates:")
for s in students:
    d = s.to_dict()
    lu = d.get('lastUpdated') or d.get('lastActivityAt')
    bottles = d.get('totalBottlesLifetime') or 0
    name = d.get('fullName', 'Unknown')
    if lu and bottles > 0:
        if hasattr(lu, 'astimezone'):
            lu_local = lu.astimezone().replace(tzinfo=None)
        else:
            lu_local = lu
        print(f"  {name}: {lu_local} ({bottles} lifetime bottles)")
