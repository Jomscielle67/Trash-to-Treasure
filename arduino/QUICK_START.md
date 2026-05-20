# 🚀 Quick Start Guide - Real-Time System

## 1️⃣ Upload Arduino Code

### QR Scanner Arduino (COM4)
```
1. Open Arduino IDE
2. Open: qr_arduino.ino
3. Select correct board and COM4 port
4. Click Upload
5. Open Serial Monitor (9600 baud)
```

### Bottle Sensor Arduino (COM3)
```
1. Open Arduino IDE
2. Open: bottle_sensor.ino
3. Select correct board and COM3 port
4. Click Upload
5. Open Serial Monitor (9600 baud)
```

## 2️⃣ Setup Firebase

```
1. Place serviceAccountKey.json in Super_User folder
2. Verify path in bridge.py: "../../serviceAccountKey.json"
3. Ensure Firebase rules allow writes to 'students' collection
```

## 3️⃣ Run the Bridge

```bash
cd arduino/qr_arduino
python bridge.py
```

**Expected Output:**
```
✅ Firebase initialized successfully
✅ QR Scanner: COM4
✅ Bottle Sensor: COM3
🚀 Bridge running... (Ctrl+C to stop)
```

## 4️⃣ Test the System

### Step 1: Open Flutter App
```
- Navigate to QR Screen
- Show QR code to scanner
```

### Step 2: Wait for Session Start
```
- QR Scanner beeps (success)
- LED turns on (green)
- LCD shows student name
- Bridge shows: "👤 NEW SESSION: [student_id]"
```

### Step 3: Insert Bottle
```
- Place bottle in sensor (7-12cm range)
- Buzzer beeps
- LCD updates count
- Bridge shows: "🍾 Bottle detected"
- Firebase updates instantly ✅
```

### Step 4: Check Firebase
```
- Open Firebase Console
- Navigate to students collection
- Find student by studentID
- Verify points and bottles increased by 1
```

### Step 5: Wait for Timeout
```
- Don't insert bottles for 15 seconds
- QR Scanner LED turns off
- LCD shows "Scan QR code to start..."
- Bridge shows: "🏁 SESSION ENDED"
```

## ✅ Success Indicators

| Component | Success Sign |
|-----------|-------------|
| QR Scanner | Green LED ON, 2 beeps |
| Bottle Sensor | "Bottle Accepted!" on LCD |
| Bridge | "✅ Firebase updated" message |
| Firebase | Points/bottles increased by 1 |

## ❌ Error Indicators

| Component | Error Sign | Solution |
|-----------|-----------|----------|
| QR Scanner | Red LED, error beep | Re-scan QR code |
| Bottle Sensor | "Rejected!" on LCD | Check bottle size (7-12cm) |
| Bridge | "❌ Firebase update error" | Check Firebase connection |
| Bridge | "⚠️ No Firebase connection" | Check serviceAccountKey.json |

## 🔧 Common Issues

### Bridge won't start
```bash
# Check COM ports
python -m serial.tools.list_ports

# Verify ports in bridge.py match actual ports
QR_SCANNER_PORT = "COM4"  # Update if different
BOTTLE_SENSOR_PORT = "COM3"  # Update if different
```

### Session doesn't start
```
1. Check QR Scanner serial monitor
2. Verify "SESSION_START:student_id" message sent
3. Check bridge console for received message
4. Verify Bottle Sensor receives "STUDENT:student_id"
```

### Bottles not counted
```
1. Check ultrasonic sensor distance (7-12cm optimal)
2. Verify bottle_sensor.ino serial output shows detection
3. Check bridge receives "BOTTLE:student_id,1" message
4. Verify Firebase connection in bridge console
```

### Firebase not updating
```
1. Check serviceAccountKey.json exists and path is correct
2. Verify Firebase rules allow writes
3. Check internet connection
4. Look for error messages in bridge console
5. Check unsent_data.json for backed up data
```

## 📊 Monitor System Status

### QR Scanner (COM4) Serial Monitor:
```
✓ System Ready - Waiting for QR codes...
STATUS:IDLE

>>> Scan Started...
✓ QR CODE SCAN SUCCESSFUL
✓ SESSION STARTED
Student ID: 2021-12345
SESSION_START:2021-12345

⏱️  Session timeout (15 seconds of inactivity)
SESSION_END:2021-12345
STATUS:IDLE
```

### Bottle Sensor (COM3) Serial Monitor:
```
🍾 Bottle Sensor Ready
⏳ Waiting for next student...

✅ Session started: 2021-12345
✅ Bottle #1 → Sent to Firebase for 2021-12345
✅ Bottle #2 → Sent to Firebase for 2021-12345

🔄 Session ended
⏳ Waiting for next student...
```

### Bridge Console:
```
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

## 🎯 Testing Checklist

- [ ] Both Arduinos connected and responding
- [ ] Bridge connects to both COM ports
- [ ] Firebase initialized successfully
- [ ] QR code scan starts session
- [ ] Bottle detection triggers Firebase update
- [ ] Points increase immediately in Firebase
- [ ] Session ends after 15 seconds inactivity
- [ ] System resets and ready for next student
- [ ] LED indicators working correctly
- [ ] LCD displays correct information
- [ ] Failed updates saved to unsent_data.json

## 📞 Need Help?

1. Check both Arduino serial monitors for debug info
2. Review bridge.py console output
3. Check REALTIME_SYSTEM.md for detailed docs
4. Verify all connections in TROUBLESHOOTING.md

---

**System Version:** 4.0 - Real-Time Updates  
**Last Updated:** October 16, 2025
