from services.firebase_service import db
from models.machine_model import Machine
from datetime import datetime

print("=== MACHINES COLLECTION ===")
docs = list(db.collection('machines').stream())
print(f"Total machines: {len(docs)}")
for doc in docs:
    d = doc.to_dict()
    print(f"\nDoc ID: {doc.id}")
    for k, v in d.items():
        print(f"  {k}: {v}")

print("\n=== MACHINE MODEL get_all_machines() ===")
machines = Machine.get_all_machines()
print(f"Returned: {len(machines)} machines")
for m in machines:
    print(f"  id={m.id} machine_id={m.machine_id} location={m.location}")
    print(f"  status={m.status} capacity={m.capacity} current_bottles={m.current_bottles}")
    print(f"  bottles_collected={m.bottles_collected} fill%={m.get_fill_percentage()}")
    print(f"  last_maintenance={m.last_maintenance} last_online={m.last_online}")
    print(f"  updated_by={m.updated_by}")

print("\n=== STATISTICS ===")
stats = Machine.get_machine_statistics()
for k,v in stats.items():
    print(f"  {k}: {v}")

print(f"\nToday: {datetime.now()}")
