"""
============================================================
T2T BRIDGE - Three-Port Real-Time Firebase Bridge
============================================================

ARCHITECTURE
  MH-ET Live Scanner + IR + Capacitive Sensor
       |
  [qr_arduino (COM6 / CH340)]
       |
       |─── QR:<uid>         → lookup student in Firebase
       |─── IR:ALERT/CLEAR   → forward to bottle_sensor
       |─── MATERIAL:<type>  → decide ACCEPT or REJECT
       |
  [bridge.py]
       |
  [bottle_sensor (COM3 / FTDI)]
   Ultrasonic + Buzzer + LCD
       |
       ← STUDENT:<name>:<id>
       ← ACCEPTED / REJECTED:<why>
       ← OBSTACLE:1 / OBSTACLE:0
       → BOTTLE_DETECTED:<id>
       → SESSION_START:<id>
       → SESSION_END:<id>

FLOW PER BOTTLE
  1. Student scans QR  → bridge looks up Firebase → sends STUDENT to bottle_sensor
  2. Bottle inserted   → bottle_sensor sends BOTTLE_DETECTED:<id>
  3. bridge sends SCAN_MATERIAL to qr_arduino
  4. qr_arduino reads capacitive sensor → sends MATERIAL:PET / GLASS / METAL
  5. If PET:   bridge sends ACCEPTED to bottle_sensor, updates Firebase
     If other: bridge sends REJECTED:<reason> to bottle_sensor (no Firebase update)

AUTHOR : T2T Capstone Team
VERSION: 6.1 — two-port, material-aware (no servor)
============================================================
"""

import serial
import serial.tools.list_ports
import time
import json
import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# ============================
#  DEBUG LOGGER
# ============================
def log(tag, msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]   # HH:MM:SS.mmm
    print("[" + ts + "] [" + level + "] [" + tag + "] " + msg)

# ============================
#  CONFIGURATION
# ============================
BAUD = 9600

# USB hardware identifiers
CH340_HWID  = "1A86:7523"   # qr_arduino    — CH340  (COM6)
FTDI_HWID   = "0403:6001"   # bottle_sensor — FTDI   (COM3)
# Run: python -m serial.tools.list_ports -v  to see all HWIDs.

def find_port(hwid_substr, label):
    log("PORT", "Scanning for " + label + " (HWID contains '" + hwid_substr + "')...")
    for port in serial.tools.list_ports.comports():
        log("PORT", "  Found: " + port.device + "  HWID=" + str(port.hwid))
        if hwid_substr.lower() in (port.hwid or "").lower():
            log("PORT", "  --> MATCHED " + label + " on " + port.device)
            return port.device
    log("PORT", "  No match for " + label, "WARN")
    return None

def detect_ports():
    if sys.platform.startswith("linux"):
        qr     = "/dev/t2t-qr"     if os.path.exists("/dev/t2t-qr")     else "/dev/ttyUSB0"
        sensor = "/dev/t2t-sensor" if os.path.exists("/dev/t2t-sensor") else "/dev/ttyUSB1"
        return qr, sensor

    qr     = find_port(CH340_HWID,  "qr_arduino (CH340)")
    sensor = find_port(FTDI_HWID,   "bottle_sensor (FTDI)")

    if qr     is None: print("[WARN] qr_arduino not found → COM6");   qr     = "COM6"
    if sensor is None: print("[WARN] bottle_sensor not found → COM3"); sensor = "COM3"

    return qr, sensor

QR_ARDUINO_PORT, BOTTLE_SENSOR_PORT = detect_ports()

FIREBASE_KEY_PATH = "../serviceAccountKey.json"
BACKUP_FILE       = os.path.join(os.path.dirname(os.path.abspath(__file__)), "unsent_data.json")
RETRY_INTERVAL    = 30


# ============================
#  FIREBASE INIT
# ============================
def initialize_firebase():
    try:
        if not firebase_admin._apps:
            key_path = os.path.normpath(
                os.path.join(os.path.dirname(os.path.abspath(__file__)), FIREBASE_KEY_PATH)
            )
            log("FIREBASE", "Key path: " + key_path)
            if not os.path.exists(key_path):
                log("FIREBASE", "Key file NOT FOUND — running in OFFLINE mode", "WARN")
                return None
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
            log("FIREBASE", "Initialised OK")
        else:
            log("FIREBASE", "Already initialised")
        return firestore.client()
    except Exception as e:
        log("FIREBASE", "Init failed: " + str(e), "ERR")
        log("FIREBASE", "Running in OFFLINE mode", "WARN")
        return None


# ============================
#  STUDENT LOOKUP
# ============================
def get_student_info(db, uid):
    if db is None:
        return None
    try:
        # The Flutter QR code encodes student!.id = Firebase Auth UID = Firestore doc ID.
        # Primary lookup: by document ID (fast, no index needed)
        doc_ref = db.collection("students").document(uid).get()
        if doc_ref.exists:
            data = doc_ref.to_dict()
            name = (
                data.get("fullName")
                or data.get("name")
                or (data.get("firstName", "") + " " + data.get("lastName", "")).strip()
                or data.get("email", uid)
            )
            student_id_field = data.get("studentID", uid).strip()
            print("[DEBUG] Found by docID=" + uid + "  studentID=" + student_id_field + "  name=" + name)
            # Return the doc ID as the key — update_student_points uses it to write back
            return {"name": name, "studentID": uid, "studentIDField": student_id_field}

        # Fallback: QR encodes the studentID field value instead of doc ID
        results = (
            db.collection("students")
              .where("studentID", "==", uid)
              .limit(1)
              .get()
        )
        if results:
            data = results[0].to_dict()
            name = (
                data.get("fullName")
                or data.get("name")
                or (data.get("firstName", "") + " " + data.get("lastName", "")).strip()
                or data.get("email", uid)
            )
            doc_id = results[0].id
            print("[DEBUG] Found by studentID field  docID=" + doc_id + "  name=" + name)
            return {"name": name, "studentID": doc_id, "studentIDField": uid}

        print("[DEBUG] No student matched for QR value: '" + uid + "'")
        return None
    except Exception as e:
        print("[ERR] Student lookup error: " + str(e))
        return None


# ============================
#  FIREBASE UPDATE
# ============================
def update_student_points(db, student_doc_id, bottles_to_add):
    """Update student points/bottles by Firestore document ID (= Firebase Auth UID)."""
    if db is None:
        log("FB", "Firebase offline — queuing to backup", "WARN")
        return False
    try:
        log("FB", "Updating doc '" + student_doc_id + "' +" + str(bottles_to_add) + " bottle(s)")
        doc_ref = db.collection("students").document(student_doc_id)
        doc     = doc_ref.get()
        if not doc.exists:
            log("FB", "Student doc not found: '" + student_doc_id + "'", "ERR")
            return False

        student_data    = doc.to_dict()
        current_points  = student_data.get("points", 0)
        current_bottles = student_data.get("bottles", 0)
        new_points      = current_points  + bottles_to_add
        new_bottles     = current_bottles + bottles_to_add

        doc_ref.update({
            "points":               new_points,
            "bottles":              new_bottles,
            "totalBottlesLifetime": firestore.Increment(bottles_to_add),
            "totalPointsEarned":    firestore.Increment(bottles_to_add),
            "lastUpdated":          firestore.SERVER_TIMESTAMP,
        })

        student_id_field = student_data.get("studentID", student_doc_id)
        log("FB", "Updated [" + student_id_field + "]  points " + str(current_points) + "->" + str(new_points) + "  bottles " + str(current_bottles) + "->" + str(new_bottles))
        return True

    except Exception as e:
        log("FB", "Update error: " + str(e), "ERR")
        return False


# ============================
#  OFFLINE BACKUP
# ============================
def load_unsent_data():
    if os.path.exists(BACKUP_FILE):
        with open(BACKUP_FILE, "r") as f:
            try:
                return json.load(f)
            except json.JSONDecodeError:
                return []
    return []

def save_unsent_data(data_list):
    with open(BACKUP_FILE, "w") as f:
        json.dump(data_list, f, indent=2)

def save_to_backup(student_id, bottles):
    unsent = load_unsent_data()
    unsent.append({
        "student_id": student_id,
        "bottles":    bottles,
        "timestamp":  datetime.now().isoformat(),
    })
    save_unsent_data(unsent)
    print("[OFFLINE] Saved: " + student_id + " +" + str(bottles) + " bottle(s)")

def retry_unsent_data(db):
    data_list = load_unsent_data()
    if not data_list or db is None:
        return
    print("\n[RETRY] Retrying " + str(len(data_list)) + " offline record(s)...")
    succeeded = []
    for record in data_list:
        if update_student_points(db, record["student_id"], record["bottles"]):
            succeeded.append(record)
            time.sleep(0.3)
    remaining = [d for d in data_list if d not in succeeded]
    save_unsent_data(remaining)
    if succeeded:  print("[OK] Synced " + str(len(succeeded)) + " record(s)")
    if remaining:  print("[OFFLINE] Still pending: " + str(len(remaining)) + " record(s)")


# ============================
#  MAIN
# ============================
def main():
    print("\n" + "=" * 60)
    print("  T2T BRIDGE  -  Two-Port Material-Aware Bridge  v6.1")
    print("=" * 60 + "\n")

    db = initialize_firebase()

    print("qr_arduino    → " + QR_ARDUINO_PORT)
    print("bottle_sensor → " + BOTTLE_SENSOR_PORT)
    print()

    try:
        qr_port     = serial.Serial(QR_ARDUINO_PORT,    BAUD, timeout=0.1)
        sensor_port = serial.Serial(BOTTLE_SENSOR_PORT, BAUD, timeout=0.1)
    except Exception as e:
        log("SERIAL", "Could not open serial port: " + str(e), "ERR")
        return

    log("SERIAL", "Both serial ports open:")
    log("SERIAL", "  qr_arduino    → " + QR_ARDUINO_PORT)
    log("SERIAL", "  bottle_sensor → " + BOTTLE_SENSOR_PORT)
    print("\nBridge running  (Ctrl+C to stop)\n")
    print("-" * 60)

    last_retry            = time.time()
    pending_student       = None     # studentID waiting for material scan
    pending_student_time  = None     # when BOTTLE_DETECTED was received (for timeout)

    try:
        while True:
            # ── Periodic offline retry ──────────────────────────
            if time.time() - last_retry > RETRY_INTERVAL:
                retry_unsent_data(db)
                last_retry = time.time()

            # ── Material scan timeout (5 s) ──────────────────────
            if pending_student and pending_student_time and \
               (time.time() - pending_student_time > 5.0):
                log("CAP", "Scan timeout (5s) — qr_arduino did not respond", "WARN")
                sensor_port.write(b"REJECTED:TIMEOUT\n")
                sensor_port.flush()
                log("SENSOR", "Sent REJECTED:TIMEOUT to bottle_sensor")
                pending_student      = None
                pending_student_time = None

            # ── Read qr_arduino ──────────────────────────────
            if qr_port.in_waiting:
                raw = qr_port.readline().decode("utf-8", errors="ignore").strip()

                # Print everything except noisy periodic lines
                if raw and raw not in ("READY", "HEARTBEAT") \
                        and not raw.startswith("[BYTE]") \
                        and not raw.startswith("QR baud") \
                        and not raw.startswith("Waiting") \
                        and not raw.startswith("[CAP-LIVE]"):
                    log("QR-ARD", raw)

                if raw == "READY":
                    log("QR-ARD", "qr_arduino online")
                elif raw == "HEARTBEAT":
                    pass  # suppress heartbeat noise; remove pass to log it

                # IR → forward to bottle_sensor
                if raw.startswith("IR:ALERT"):
                    sensor_port.write(b"OBSTACLE:1\n")
                    sensor_port.flush()
                    log("IR", "IR obstacle detected → sent OBSTACLE:1 to bottle_sensor", "WARN")
                elif raw.startswith("IR:CLEAR"):
                    sensor_port.write(b"OBSTACLE:0\n")
                    sensor_port.flush()
                    log("IR", "IR cleared → sent OBSTACLE:0 to bottle_sensor")

                # Material scan result
                elif raw.startswith("MATERIAL:"):
                    material = raw[9:].strip().upper()   # PET / GLASS / METAL
                    sid = pending_student
                    pending_student = None

                    # ── Capacitive detection banner ──────────────────
                    print("\n" + "=" * 60)
                    if material == "PET":
                        print("  [CAP SENSOR]  DETECTED: PET PLASTIC BOTTLE  ✓")
                        print("  Action : ACCEPTED — gate will OPEN")
                    elif material == "GLASS":
                        print("  [CAP SENSOR]  DETECTED: NOT PET BOTTLES  ✗")
                        print("  Action : REJECTED — gate stays CLOSED")
                    elif material == "METAL":
                        print("  [CAP SENSOR]  DETECTED: NOT PET BOTTLES  ✗")
                        print("  Action : REJECTED — gate stays CLOSED")
                    else:
                        print("  [CAP SENSOR]  DETECTED: UNKNOWN (" + material + ")  ✗")
                        print("  Action : REJECTED — gate stays CLOSED")
                    print("  Student: " + str(sid))
                    print("=" * 60 + "\n")
                    # ─────────────────────────────────────────────────

                    if material == "PET":
                        # Accept: tell bottle_sensor, update Firebase
                        sensor_port.write(b"ACCEPTED\n")
                        sensor_port.flush()
                        if sid:
                            if not update_student_points(db, sid, 1):
                                save_to_backup(sid, 1)
                    else:
                        # Reject: tell bottle_sensor why
                        msg = ("REJECTED:" + material + "\n").encode("utf-8")
                        sensor_port.write(msg)
                        sensor_port.flush()
                    pending_student_time = None

                # QR scan
                elif raw.startswith("QR:") or raw.startswith("ID:"):
                    uid = raw[3:].strip()
                    log("QR", "Raw scan received: '" + uid + "'  (len=" + str(len(uid)) + ")")
                    if len(uid) >= 3:
                        student = get_student_info(db, uid)
                        if student:
                            name = student["name"]
                            sid  = student["studentID"]
                            sid_field = student.get("studentIDField", "?")
                            log("QR", "Student found: name='" + name + "'  studentID='" + sid_field + "'  docID='" + sid + "'")
                            msg  = ("STUDENT:" + name + ":" + sid + "\n").encode("utf-8")
                            sensor_port.write(msg)
                            sensor_port.flush()
                            log("SENSOR", "Sent STUDENT:" + name + ":" + sid)
                        else:
                            sensor_port.write(b"ERROR:notfound\n")
                            sensor_port.flush()
                            log("QR", "Student NOT found for uid='" + uid + "' — sent ERROR:notfound", "WARN")
                    else:
                        log("QR", "Uid too short (len=" + str(len(uid)) + "), ignored", "WARN")

            # ── Read bottle_sensor (COM4) ────────────────────────
            if sensor_port.in_waiting:
                raw = sensor_port.readline().decode("utf-8", errors="ignore").strip()
                if not raw or raw.startswith("[DIST]"):
                    pass

                elif raw == "READY":
                    print("[bridge] bottle_sensor online")

                elif raw.startswith("BOTTLE_DETECTED:"):
                    sid = raw[16:].strip()
                    pending_student      = sid
                    pending_student_time = time.time()
                    print("\n[BOTTLE] Detected for [" + sid + "] — requesting material scan")
                    qr_port.write(b"SCAN_MATERIAL\n")
                    qr_port.flush()

                elif raw.startswith("SESSION_START:"):
                    sid = raw.split(":", 1)[1].strip()
                    print("\n" + "-" * 60)
                    print("[SESSION] STARTED  [" + sid + "]")
                    print("-" * 60)

                elif raw.startswith("SESSION_END:"):
                    sid = raw.split(":", 1)[1].strip()
                    pending_student = None
                    print("\n" + "-" * 60)
                    print("[SESSION] ENDED    [" + sid + "]")
                    print("-" * 60 + "\n")

                else:
                    print("[SENSOR] " + raw)

            time.sleep(0.02)

    except KeyboardInterrupt:
        log("BRIDGE", "Stopped by user (Ctrl+C)")
    finally:
        log("BRIDGE", "Closing serial ports...")
        qr_port.close()
        sensor_port.close()
        print("Serial ports closed.")
        print("Goodbye!\n")


if __name__ == "__main__":
    main()
