# 📊 T2T System Flow Diagram

## 🔄 Complete Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         STUDENT SCANS QR CODE                            │
│                         (Flutter App on Phone)                           │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          QR SCANNER ARDUINO                              │
│                              (COM4)                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Reads QR code (student ID)                                   │    │
│  │ 2. Validates ID length (3-50 chars)                            │    │
│  │ 3. Starts session (activeStudentID = "2021-12345")            │    │
│  │ 4. Starts 15-second timer                                      │    │
│  │ 5. Turns ON green LED                                          │    │
│  │ 6. Beeps twice (success)                                       │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                   │                                      │
│                    Sends: SESSION_START:2021-12345                      │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          PYTHON BRIDGE                                   │
│                      (Runs on Computer)                                  │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Receives: SESSION_START:2021-12345                          │    │
│  │ 2. Stores: active_student = "2021-12345"                       │    │
│  │ 3. Queries Firebase to verify student exists                   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                      │                              │                    │
│        Sends: STUDENT:2021-12345                   │                    │
│              (to Bottle Sensor)                    │                    │
└──────────────┬──────────────────────────────────────┼────────────────────┘
               │                                      │
               ▼                                      │
┌─────────────────────────────────────────────────────┐                   │
│       BOTTLE SENSOR ARDUINO                         │                   │
│            (COM3)                                   │                   │
│  ┌────────────────────────────────────────────┐    │                   │
│  │ 1. Receives: STUDENT:2021-12345            │    │                   │
│  │ 2. Sets: currentUser = "2021-12345"        │    │                   │
│  │ 3. Sets: hasActiveUser = true              │    │                   │
│  │ 4. LCD shows: "Hello Student!"             │    │                   │
│  │ 5. LCD shows: "2021-12345"                 │    │                   │
│  │ 6. Beeps (session start)                   │    │                   │
│  │ 7. LCD shows: "Insert bottle..."           │    │                   │
│  └────────────────────────────────────────────┘    │                   │
│                     │                               │                   │
│              Ready for bottles                      │                   │
└─────────────────────┼───────────────────────────────┘                   │
                      │                                                   │
        ┌─────────────▼────────────┐                                      │
        │  STUDENT INSERTS BOTTLE  │                                      │
        └─────────────┬────────────┘                                      │
                      │                                                   │
┌─────────────────────▼───────────────────────────────┐                   │
│       BOTTLE SENSOR ARDUINO                         │                   │
│  ┌────────────────────────────────────────────┐    │                   │
│  │ 1. Ultrasonic sensor: 10cm detected        │    │                   │
│  │ 2. Validates: 7cm ≤ 10cm ≤ 12cm ✅         │    │                   │
│  │ 3. Increments: sessionBottleCount++        │    │                   │
│  │ 4. LCD shows: "Bottle Accepted!"           │    │                   │
│  │ 5. LCD shows: "Total: 1"                   │    │                   │
│  │ 6. Beeps (success)                         │    │                   │
│  │ 7. LED blinks                              │    │                   │
│  └────────────────────────────────────────────┘    │                   │
│                     │                               │                   │
│        Sends: BOTTLE:2021-12345,1                   │                   │
└─────────────────────┼───────────────────────────────┘                   │
                      │                                                   │
                      ▼                                                   │
┌─────────────────────────────────────────────────────────────────────────┐
│                          PYTHON BRIDGE                                   │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Receives: BOTTLE:2021-12345,1                               │    │
│  │ 2. Queries Firebase: students.where('studentID', '==', '...')  │    │
│  │ 3. Gets current: points=10, bottles=5                          │    │
│  │ 4. Calculates: new_points=11, new_bottles=6                    │    │
│  │ 5. Updates Firebase:                                           │    │
│  │    - points: 10 → 11                                           │    │
│  │    - bottles: 5 → 6                                            │    │
│  │    - lastUpdated: [timestamp]                                  │    │
│  │ 6. Prints: "✅ Firebase updated: 2021-12345"                   │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                      │                                                   │
│        Sends: BOTTLE_DETECTED (to QR Scanner)                           │
└──────────────────────┼───────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          QR SCANNER ARDUINO                              │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Receives: BOTTLE_DETECTED                                   │    │
│  │ 2. Resets timer: lastActivityTime = now                        │    │
│  │ 3. Still has 15 seconds before timeout                         │    │
│  │ 4. Session continues...                                        │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────┐
│  STUDENT INSERTS 2nd, 3rd BOTTLE  │
│     (Process repeats for each)     │
└────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                   15 SECONDS OF NO ACTIVITY                              │
└──────────────────────────────────┬──────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          QR SCANNER ARDUINO                              │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Checks: (now - lastActivityTime) >= 15000ms                │    │
│  │ 2. Timeout detected!                                           │    │
│  │ 3. Prints: "⏱️  Session timeout"                               │    │
│  │ 4. Sends: SESSION_END:2021-12345                               │    │
│  │ 5. Resets: activeStudentID = ""                               │    │
│  │ 6. Sets: sessionActive = false                                │    │
│  │ 7. Turns OFF green LED                                        │    │
│  │ 8. Beeps (end session)                                        │    │
│  │ 9. Prints: "STATUS:IDLE"                                      │    │
│  └────────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────┬──────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          PYTHON BRIDGE                                   │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. Receives: SESSION_END:2021-12345                            │    │
│  │ 2. Prints: "🏁 SESSION ENDED: 2021-12345"                      │    │
│  │ 3. Clears: active_student = None                               │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                      │                                                   │
│        Sends: SESSION_END (to Bottle Sensor)                            │
└──────────────────────┼───────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│       BOTTLE SENSOR ARDUINO                         │                   │
│  ┌────────────────────────────────────────────┐    │                   │
│  │ 1. Receives: SESSION_END                   │    │                   │
│  │ 2. Calls: resetSession()                   │    │                   │
│  │ 3. Clears: currentUser = ""                │    │                   │
│  │ 4. Sets: hasActiveUser = false             │    │                   │
│  │ 5. Resets: sessionBottleCount = 0          │    │                   │
│  │ 6. LCD shows: "Scan QR code to start..."   │    │                   │
│  │ 7. Ready for next student                  │    │                   │
│  └────────────────────────────────────────────┘    │                   │
└─────────────────────────────────────────────────────┘                   │

┌─────────────────────────────────────────────────────────────────────────┐
│                       SYSTEM BACK TO IDLE                                │
│                   Ready for next student to scan                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## ⚡ Real-Time Update Details

```
Every Bottle Scan:
┌──────────────┐    BOTTLE:ID,1    ┌──────────────┐    Firebase     ┌──────────────┐
│   Bottle     │ ───────────────►  │    Bridge    │ ──────────────►  │   Firebase   │
│   Sensor     │                   │   (Python)   │   Update NOW    │   Firestore  │
└──────────────┘                   └──────────────┘                 └──────────────┘
      │                                    │                               │
      │                                    │                               │
      └─────────────── BOTTLE_DETECTED ────┘                               │
                      (resets timer)                                       │
                                                                           │
                                                  ┌────────────────────────┘
                                                  │
                                                  ▼
                                          Student sees points
                                          update in app instantly!
```

## 🔢 Data Flow Example

```
Initial State:
  Student: 2021-12345
  Points: 10
  Bottles: 5

Action: Student scans QR + inserts 3 bottles

Timeline:
  T+0s:  QR Scan → Session Start
  T+2s:  Bottle 1 → Firebase: points=11, bottles=6 ✅
  T+5s:  Bottle 2 → Firebase: points=12, bottles=7 ✅
  T+8s:  Bottle 3 → Firebase: points=13, bottles=8 ✅
  T+23s: (15s since last bottle) → Session End

Final State:
  Student: 2021-12345
  Points: 13 (+3)
  Bottles: 8 (+3)
```

## 🎯 Key Advantages

```
OLD SYSTEM:
┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐
│ Scan │  │ Scan │  │ Scan │  │ Scan │  │ Scan │
│  1   │  │  2   │  │  3   │  │  4   │  │  5   │
└───┬──┘  └───┬──┘  └───┬──┘  └───┬──┘  └───┬──┘
    └────────┴────────┴────────┴────────┴─────►  Firebase Update (ONCE)
                                                  After 5 bottles only

NEW SYSTEM:
┌──────┐     Firebase Update (points+1, bottles+1) ✅
│ Scan │  ──────────────────────────────►
│  1   │
└──────┘

┌──────┐     Firebase Update (points+1, bottles+1) ✅
│ Scan │  ──────────────────────────────►
│  2   │
└──────┘

┌──────┐     Firebase Update (points+1, bottles+1) ✅
│ Scan │  ──────────────────────────────►
│  3   │
└──────┘
      └──► INSTANT feedback for every bottle!
```

## 🔄 Timer Reset Mechanism

```
Session Timeline:

0s ───────────────► QR Scan (Session Start)
                    Timer: 15 seconds remaining
                    
3s ───────────────► Bottle 1 detected
                    Timer: RESET to 15 seconds
                    
8s ───────────────► Bottle 2 detected
                    Timer: RESET to 15 seconds
                    
20s ──────────────► Bottle 3 detected
                    Timer: RESET to 15 seconds
                    
35s ──────────────► No activity for 15 seconds
                    Timer: EXPIRED
                    Session End
                    Back to IDLE
```

---

**System Version:** 4.0 - Real-Time Updates  
**Visual Guide - Workflow & Data Flow**
