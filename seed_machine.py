"""One-time script to seed the T2T Machine 1 document in Firestore."""
from services.firebase_service import db
from datetime import datetime

MACHINE_ID = "MCN001"
MACHINE_DOC = {
    "machineId": MACHINE_ID,
    "name": "T2T Machine 1",
    "location": "Main Campus",
    "status": "active",
    "capacity": 100,
    "currentBottles": 0,
    "bottlesCollected": 0,
    "lastMaintenance": None,
    "lastOnline": datetime.utcnow(),
    "createdAt": datetime.utcnow(),
    "updatedBy": "system",
    "maintenanceSchedule": 7,
    "notes": "Primary bottle collection machine"
}

ref = db.collection("machines").document(MACHINE_ID)
existing = ref.get()
if existing.exists:
    print(f"Machine {MACHINE_ID} already exists: {existing.to_dict()}")
else:
    ref.set(MACHINE_DOC)
    print(f"Created machine document: {MACHINE_ID}")
    print(MACHINE_DOC)
