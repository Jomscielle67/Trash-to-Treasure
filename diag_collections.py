from services.firebase_service import db

# List all collections
print('=== COLLECTIONS ===')
cols = [c.id for c in db.collections()]
print(cols)
print()

# Check students for bottle-related data
print('=== STUDENTS SAMPLE ===')
students = list(db.collection('students').limit(3).stream())
for s in students:
    d = s.to_dict()
    keys = list(d.keys())
    print(f'Student keys: {keys}')
    bottles = d.get('totalBottles') or d.get('bottles') or d.get('total_bottles')
    points = d.get('points') or d.get('totalPoints')
    print(f'  points={points}, bottles={bottles}')
    print()
