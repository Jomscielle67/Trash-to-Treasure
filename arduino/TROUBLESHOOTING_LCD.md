# 🔧 Troubleshooting: LCD Not Changing After QR Scan

## The Problem
When you scan a QR code with the QR Scanner Arduino, the Bottle Sensor LCD doesn't change from "Waiting..." to show the student info.

## Root Cause Analysis

The system has 3 components that must communicate:
```
QR Scanner (COM4) → Bridge (Python) → Bottle Sensor (COM3)
```

If the LCD doesn't change, the communication chain is broken somewhere.

---

## Step-by-Step Debugging

### ✅ Step 1: Verify Hardware Connections

**Both Arduinos should be connected to YOUR COMPUTER via USB:**
- QR Scanner Arduino → USB Cable → Computer (COM4)
- Bottle Sensor Arduino → USB Cable → Computer (COM3)

**They should NOT be connected to each other!**

---

### ✅ Step 2: Test Bottle Sensor Alone

1. **Open Arduino IDE**
2. **Open Serial Monitor** on COM3 (9600 baud)
3. **Type this command and press Enter:**
   ```
   STUDENT:TEST123
   ```
4. **Expected Result:**
   - LCD should change to "Hello Student!" / "TEST123"
   - Serial Monitor shows: "✅ Session started for: TEST123"
   - Serial Monitor shows: "   LCD updated!"

**If this works:** ✅ Bottle Sensor is OK  
**If this doesn't work:** ❌ Problem with Bottle Sensor (see fixes below)

---

### ✅ Step 3: Test QR Scanner Alone

1. **Open Arduino IDE**
2. **Open Serial Monitor** on COM4 (9600 baud)
3. **Scan a QR code from your Flutter app**
4. **Expected Result:**
   - Serial Monitor shows: "✓ QR CODE SCAN SUCCESSFUL"
   - Serial Monitor shows: "SESSION_START:student_id"

**If this works:** ✅ QR Scanner is OK  
**If this doesn't work:** ❌ Problem with QR Scanner (check QR_BAUD_DETECTOR.md)

---

### ✅ Step 4: Test Python Bridge

1. **CLOSE all Arduino IDE Serial Monitors** (very important!)
2. **Open PowerShell/Terminal**
3. **Navigate to bridge directory:**
   ```powershell
   cd "C:\Users\Vincent\Desktop\capstone\t2t\Super_User\arduino\qr_arduino"
   ```
4. **Run bridge:**
   ```powershell
   python bridge.py
   ```
5. **Expected Result:**
   ```
   ✅ Firebase initialized successfully
   ✅ QR Scanner: COM4
   ✅ Bottle Sensor: COM3
   🚀 Bridge running...
   ```

**If you see errors:** See "Bridge Connection Issues" below

---

### ✅ Step 5: Test Complete Flow

**With bridge.py running:**

1. **Scan a QR code** with your Flutter app
2. **Watch bridge console output:**
   ```
   ==================================================
   👤 NEW SESSION: 2021-12345
   ==================================================
   ```
3. **Check Bottle Sensor LCD:**
   - Should change to "Hello Student!"
   - Should show student ID

4. **If LCD changes:** ✅ System working!
5. **If LCD doesn't change:** Continue to specific fixes below

---

## Common Issues & Fixes

### 🔴 Issue 1: Serial Monitor is Open
**Symptoms:** Bridge says "Serial connection failed" or "Access denied"

**Fix:**
```
1. Close ALL Arduino IDE windows
2. Close Serial Monitors
3. Restart bridge.py
```

---

### 🔴 Issue 2: Wrong COM Ports
**Symptoms:** Bridge connects but no communication

**How to find correct ports:**
```powershell
python -m serial.tools.list_ports
```

Or check Windows Device Manager:
1. Win + X → Device Manager
2. Expand "Ports (COM & LPT)"
3. Look for Arduino devices

**Fix in bridge.py (lines 28-29):**
```python
QR_SCANNER_PORT = "COM4"      # Change to your actual port
BOTTLE_SENSOR_PORT = "COM3"   # Change to your actual port
```

---

### 🔴 Issue 3: LCD Not Initialized
**Symptoms:** LCD backlight on but no text, or garbled text

**Fix:**
```cpp
// In bottle_sensor.ino, try different LCD address:
LiquidCrystal_I2C lcd(0x3F, 16, 2);  // Try 0x3F instead of 0x27
```

**How to find LCD address:**
Upload this I2C scanner sketch to find your LCD's address:
```cpp
#include <Wire.h>

void setup() {
  Wire.begin();
  Serial.begin(9600);
  Serial.println("I2C Scanner");
}

void loop() {
  for(byte address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.print("Found device at: 0x");
      Serial.println(address, HEX);
    }
  }
  delay(5000);
}
```

---

### 🔴 Issue 4: Bridge Not Sending to Bottle Sensor
**Symptoms:** Bridge shows "NEW SESSION" but LCD doesn't change

**Add debug to bridge.py (after line 220):**
```python
# After: bottle_sensor.write(f"STUDENT:{student_id}\n".encode())
print(f"📤 Sent to Bottle Sensor: STUDENT:{student_id}")
time.sleep(0.1)  # Small delay
```

**Check Bottle Sensor Serial Output:**
You should see:
```
📥 Received: [STUDENT:2021-12345] Length: 20
✅ Session started for: 2021-12345
   User length: 10
   LCD updated!
```

If you don't see "📥 Received", the bridge isn't sending data properly.

---

### 🔴 Issue 5: Bottle Sensor Not Reading Serial
**Symptoms:** No "📥 Received" messages in debug output

**Fix 1: Verify Serial.begin() in setup():**
```cpp
void setup() {
  Serial.begin(9600);  // Must be 9600 to match bridge
  // ... rest of setup
}
```

**Fix 2: Check for data more frequently:**
The issue might be timing. The bottle sensor already checks Serial in loop(), but add this debug:

```cpp
void loop() {
  // At the very start of loop():
  if (Serial.available() > 0) {
    Serial.print(F("🔔 Serial available: "));
    Serial.print(Serial.available());
    Serial.println(F(" bytes"));
  }
  
  // ... rest of your code
```

---

### 🔴 Issue 6: Message Format Wrong
**Symptoms:** Bridge sends data but bottle sensor doesn't recognize it

**Check message format in bridge (line 220):**
```python
bottle_sensor.write(f"STUDENT:{student_id}\n".encode())
```

Must have:
- `STUDENT:` prefix (capital letters)
- Student ID
- `\n` newline at end

**Verify in bottle_sensor.ino (line 68):**
```cpp
if (msg.startsWith("STUDENT:")) {
  currentUser = msg.substring(8);  // Remove "STUDENT:" (8 characters)
  currentUser.trim();
  // ...
}
```

---

## Quick Test Script

Save this as `test_bottle_sensor.py` in the same folder:

```python
import serial
import time

# Change to your Bottle Sensor port
PORT = "COM3"
BAUD = 9600

print(f"Connecting to {PORT}...")
ser = serial.Serial(PORT, BAUD, timeout=1)
time.sleep(2)  # Wait for Arduino to reset

print("\nSending test message...")
ser.write(b"STUDENT:TEST123\n")

print("\nWaiting for response (10 seconds)...")
start = time.time()
while time.time() - start < 10:
    if ser.in_waiting:
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        print(f"Response: {line}")

print("\nCheck your LCD - it should show:")
print("  Line 1: Hello Student!")
print("  Line 2: TEST123")

ser.close()
```

Run it:
```powershell
python test_bottle_sensor.py
```

---

## Expected Serial Output (Bottle Sensor)

When working correctly, you should see:

```
🍾 Bottle Sensor Ready
⏳ Waiting for next student...
📥 Received: [STUDENT:2021-12345] Length: 20
✅ Session started for: 2021-12345
   User length: 10
   LCD updated!
```

---

## Expected Serial Output (Bridge)

When working correctly, you should see:

```
==================================================
👤 NEW SESSION: 2021-12345
==================================================

📤 Sent to Bottle Sensor: STUDENT:2021-12345
```

---

## Still Not Working?

### Last Resort Fixes:

1. **Power cycle everything:**
   - Unplug both Arduinos
   - Close bridge.py
   - Wait 10 seconds
   - Plug in Arduinos
   - Run bridge.py

2. **Re-upload bottle_sensor.ino:**
   - Make sure to close bridge.py first
   - Upload fresh code to Bottle Sensor
   - Restart bridge.py

3. **Check USB cables:**
   - Some USB cables are power-only (no data)
   - Try different cables
   - Try different USB ports on computer

4. **Simplify the test:**
   - Upload the debug code above
   - Use Serial Monitor to manually send: `STUDENT:TEST`
   - If LCD still doesn't change, it's an LCD issue

---

## Success Checklist

- [ ] Both Arduinos connected to computer via USB
- [ ] COM ports correct in bridge.py
- [ ] Bridge connects successfully
- [ ] QR Scanner outputs SESSION_START
- [ ] Bridge receives SESSION_START
- [ ] Bridge sends STUDENT: to Bottle Sensor
- [ ] Bottle Sensor receives STUDENT: message
- [ ] LCD updates to show student info
- [ ] System ready for bottles!

---

Need more help? Check the debug output and report which step fails!
