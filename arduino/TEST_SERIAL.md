# 🔍 Serial Communication Test Guide

## Problem: LCD Not Changing When QR Code Scanned

### Diagnosis Steps

#### Step 1: Check Serial Connections
Both Arduinos should be connected to **your computer via USB**, NOT to each other!

```
Computer (Running bridge.py)
    ├── USB Cable → QR Scanner Arduino (COM4)
    └── USB Cable → Bottle Sensor Arduino (COM3)
```

#### Step 2: Test Each Arduino Separately

**Test QR Scanner Arduino:**
1. Open Arduino IDE
2. Open Serial Monitor on COM4 (9600 baud)
3. Scan a QR code
4. You should see: `SESSION_START:student_id`

**Test Bottle Sensor Arduino:**
1. Open Arduino IDE
2. Open Serial Monitor on COM3 (9600 baud)
3. Type: `STUDENT:2021-12345` and press Enter
4. LCD should change to show "Hello Student!" and "2021-12345"

#### Step 3: Test Bridge Connection

1. **Close all Arduino IDE Serial Monitors** (important!)
2. Run bridge.py:
   ```bash
   cd arduino/qr_arduino
   python bridge.py
   ```
3. Check output shows both ports connected:
   ```
   ✅ QR Scanner: COM4
   ✅ Bottle Sensor: COM3
   ```

#### Step 4: Test Full Flow

1. Keep bridge.py running
2. Scan a QR code
3. Watch bridge console for:
   ```
   👤 NEW SESSION: student_id
   ```
4. LCD should now change!

---

## Common Issues

### Issue 1: Serial Monitor Open
**Problem:** Bridge can't connect if Serial Monitor is open  
**Solution:** Close ALL Arduino IDE Serial Monitors before running bridge.py

### Issue 2: Wrong COM Ports
**Problem:** Bridge connected to wrong ports  
**Solution:** Check Device Manager, update COM ports in bridge.py

### Issue 3: Serial Buffer Not Clearing
**Problem:** Old data in serial buffer  
**Solution:** Power cycle both Arduinos or reset them

### Issue 4: Missing Newline Character
**Problem:** Arduino waiting for `\n` character  
**Solution:** Already handled in code with `readStringUntil('\n')`

---

## Quick Fix: Test Bottle Sensor Directly

Add this test code to bottle_sensor.ino temporarily to debug:

```cpp
// Add to loop() - at the very top, before everything else:
void loop() {
  // 🔍 DEBUG: Print what we receive
  if (Serial.available()) {
    String msg = Serial.readStringUntil('\n');
    msg.trim();
    
    // Print to Serial Monitor what we received
    Serial.print("📥 Received: [");
    Serial.print(msg);
    Serial.println("]");
    
    // Also print to LCD for visual confirmation
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Got: ");
    lcd.setCursor(0, 1);
    lcd.print(msg.substring(0, 16));
    delay(2000);
    
    // ... rest of your code
```

This will help you see if the message is even arriving!

---

## Test Commands

### Manual Test via Serial Monitor (COM3):
```
STUDENT:2021-12345
SESSION_END
```

### Expected LCD Behavior:
```
Before: "Trash 2 Treasure" / "Waiting..."
After STUDENT: "Hello Student!" / "2021-12345"
Then: "Insert bottle..." / "Bottles: 0"
```
