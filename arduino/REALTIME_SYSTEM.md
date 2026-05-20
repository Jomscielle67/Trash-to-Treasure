# 🚀 T2T Real-Time Bottle Scanning System

## Overview

This system provides **instant Firebase updates** for every bottle scanned. No more waiting for 5 bottles - each bottle triggers an immediate point update!

## 📋 System Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│   QR Scanner    │ ------> │  Python Bridge   │ <------ │ Bottle Sensor   │
│   (COM4)        │         │   (Firebase)     │         │   (COM3)        │
└─────────────────┘         └──────────────────┘         └─────────────────┘
        │                            │                            │
        │                            │                            │
     Scans QR                Updates Firebase              Detects Bottles
    Manages Session         in Real-Time                  Counts & Reports
```

## 🔄 Workflow

### Step 1: Student Scans QR Code
- **QR Scanner** detects student QR code
- Validates student ID
- Starts active session (15-second timeout)
- Sends `SESSION_START:student_id` to bridge
- LED stays ON during active session

### Step 2: Bridge Activates Bottle Sensor
- **Bridge** receives `SESSION_START:student_id`
- Notifies **Bottle Sensor** via `STUDENT:student_id`
- Bottle Sensor LCD shows student info
- System ready to accept bottles

### Step 3: Real-Time Bottle Processing
- **Bottle Sensor** detects bottle (ultrasonic sensor)
- Immediately sends `BOTTLE:student_id,1` to bridge
- **Bridge** updates Firebase in real-time:
  - `points = points + 1`
  - `bottles = bottles + 1`
  - `lastUpdated = timestamp`
- LCD shows running total
- Success beep/LED feedback

### Step 4: Session Timeout
- After **15 seconds** of no activity:
  - **QR Scanner** sends `SESSION_END:student_id`
  - **Bridge** notifies **Bottle Sensor**
  - System resets to idle state
  - Ready for next student

### Step 5: Activity Reset
- Each bottle detection resets the 15-second timer
- Student can keep scanning bottles
- Session only ends after 15 seconds of inactivity

## 📁 Files

### 1. `qr_arduino.ino` (QR Scanner)
**Port:** COM4  
**Features:**
- Scans QR codes from Flutter app
- Manages active session state
- 15-second inactivity timeout
- LED indicator (on during session)
- Sends session start/end events

**Key Messages:**
- `SESSION_START:student_id` - New session started
- `SESSION_END:student_id` - Session ended (timeout)
- Listens for `BOTTLE_DETECTED` to reset timer

### 2. `bottle_sensor.ino` (Bottle Detection)
**Port:** COM3  
**Features:**
- Ultrasonic bottle detection (7-12cm range)
- LCD display with student info
- Immediate bottle reporting (no batch)
- Beeper/LED feedback
- Manual reset button

**Key Messages:**
- Listens for `STUDENT:student_id` to start session
- Sends `BOTTLE:student_id,1` for each bottle
- Listens for `SESSION_END` to reset

### 3. `bridge.py` (Firebase Bridge)
**Features:**
- Connects to Firebase Firestore
- Real-time student updates
- Offline mode with backup
- Automatic retry for failed updates
- Session management coordination

**Firebase Updates:**
```python
{
  'points': current_points + 1,
  'bottles': current_bottles + 1,
  'lastUpdated': SERVER_TIMESTAMP
}
```

## 🔧 Setup Instructions

### Hardware Connections

#### QR Scanner Arduino (COM4)
```
QR Module TX  → Arduino Pin 10 (RX)
QR Module RX  → Arduino Pin 11 (TX)
LED (Green)   → Arduino Pin 7
LED (Red)     → Arduino Pin 6
Buzzer        → Arduino Pin 8
Reset Button  → Arduino Pin 2
VCC           → 5V
GND           → GND
```

#### Bottle Sensor Arduino (COM3)
```
Ultrasonic Trig → Arduino Pin 10
Ultrasonic Echo → Arduino Pin 11
Buzzer          → Arduino Pin 7
LED             → Arduino Pin 13
Reset Button    → Arduino Pin 2
LCD SDA         → Arduino A4 (I2C)
LCD SCL         → Arduino A5 (I2C)
VCC             → 5V
GND             → GND
```

### Software Setup

#### 1. Arduino Setup
```bash
# Upload qr_arduino.ino to QR Scanner Arduino (COM4)
# Upload bottle_sensor.ino to Bottle Sensor Arduino (COM3)
```

#### 2. Python Bridge Setup
```bash
# Navigate to bridge directory
cd arduino/qr_arduino

# Install dependencies (if not already installed)
pip install pyserial firebase-admin

# Place your Firebase service account key
# Copy serviceAccountKey.json to Super_User folder

# Run the bridge
python bridge.py
```

#### 3. Configuration

**Update COM Ports in bridge.py if needed:**
```python
QR_SCANNER_PORT = "COM4"      # Your QR Scanner port
BOTTLE_SENSOR_PORT = "COM3"   # Your Bottle Sensor port
```

**Adjust Firebase key path if needed:**
```python
FIREBASE_KEY_PATH = "../../serviceAccountKey.json"
```

## 📊 Firebase Structure

### Students Collection
```javascript
students/{studentId}
{
  fullName: string,
  studentID: string,  // Used for QR code matching
  email: string,
  department: string,
  points: number,     // Updated in real-time
  bottles: number,    // Updated in real-time
  lastUpdated: timestamp,
  role: "student",
  createdAt: timestamp
}
```

## 🎯 Key Features

### ✅ Real-Time Updates
- Each bottle = instant Firebase update
- No batching or waiting
- Students see points immediately in app

### ✅ Session Management
- 15-second inactivity timeout
- Automatic session reset
- LED indicator shows active session

### ✅ Offline Support
- Failed updates saved locally
- Automatic retry every 10 seconds
- No data loss

### ✅ Error Handling
- Invalid bottle rejection
- Student validation
- Connection error recovery

### ✅ User Feedback
- LCD displays student info
- Running bottle count
- Beeper for success/error
- LED indicators

## 🔍 Testing

### Test Flow
1. **Start Bridge:** `python bridge.py`
2. **Scan QR Code:** Use Flutter app QR screen
3. **Insert Bottle:** Place bottle in sensor range
4. **Check Firebase:** Verify points updated immediately
5. **Wait 15 seconds:** Session should auto-end
6. **Scan Next Student:** System ready for new session

### Expected Console Output

**Bridge:**
```
✅ Firebase initialized successfully
✅ QR Scanner: COM4
✅ Bottle Sensor: COM3
🚀 Bridge running...

==================================================
👤 NEW SESSION: 2021-12345
==================================================

🍾 Bottle detected for: 2021-12345
✅ Firebase updated: 2021-12345
   📊 Points: 10 → 11 (+1)
   🍾 Bottles: 5 → 6 (+1)

==================================================
🏁 SESSION ENDED: 2021-12345
==================================================
```

## 🐛 Troubleshooting

### Bridge won't connect to Arduino
- Check COM ports in bridge.py
- Verify Arduino drivers installed
- Check USB connections

### Firebase updates failing
- Verify serviceAccountKey.json path
- Check Firebase rules allow writes
- Check internet connection

### Session not ending after 15 seconds
- Check QR Scanner serial output
- Verify bridge is receiving messages
- Check for continuous bottle detections resetting timer

### Bottles not detected
- Adjust ultrasonic sensor distance (7-12cm optimal)
- Check bottle_sensor.ino debug output
- Verify sensor connections

## 📝 Notes

- **Minimum bottle distance:** 7cm
- **Maximum bottle distance:** 12cm
- **Session timeout:** 15 seconds
- **Retry interval:** 10 seconds
- **Points per bottle:** 1 point

## 🎉 Advantages Over Old System

| Feature | Old System | New System |
|---------|-----------|------------|
| Updates | After 5 bottles | Every bottle |
| Feedback | End of session | Real-time |
| Session | Fixed count | Time-based |
| Flexibility | Limited | High |
| User Experience | Slow | Instant |

## 📞 Support

For issues or questions:
1. Check Arduino serial monitors
2. Review bridge.py console output
3. Check Firebase console logs
4. Review this documentation

---

**Version:** 4.0  
**Date:** October 16, 2025  
**Team:** T2T Capstone
