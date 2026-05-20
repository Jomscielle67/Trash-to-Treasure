# 🔧 Troubleshooting: Sensor & LCD Issues

## Problem 1: LCD Showing Black Boxes ⬛⬛⬛

### **Quick Fix Steps:**

1. **Find Correct I2C Address**
   ```
   1. Upload `test_lcd_address.ino` to your Arduino
   2. Open Serial Monitor (9600 baud)
   3. Look for "Device found at 0x??"
   4. Note the address (usually 0x27 or 0x3F)
   ```

2. **Update LCD Address in Code**
   - Edit `bottle_sensor.ino` line 20:
   ```cpp
   // Try these addresses:
   LiquidCrystal_I2C lcd(0x27, 16, 2);  // Most common
   // OR
   LiquidCrystal_I2C lcd(0x3F, 16, 2);  // Also common
   // OR
   LiquidCrystal_I2C lcd(0x20, 16, 2);  // Less common
   ```

3. **Adjust LCD Contrast**
   - There's a blue potentiometer (screw) on the back of the LCD I2C module
   - Use a small screwdriver to turn it slowly
   - You should see the text become clearer

---

## Problem 2: Can't Read Sensor Data 📡

### **Test Each Component Separately:**

### **Step 1: Test Bottle Sensor Alone**
```
1. Disconnect from bridge.py
2. Upload bottle_sensor.ino to Arduino
3. Open Serial Monitor (9600 baud)
4. Type: STUDENT:TEST123
5. Press Enter
6. You should see:
   - LCD shows "Hello Student!"
   - Serial shows "✅ Session started for: TEST123"
7. Wave your hand near the sensor (7-12cm away)
8. You should see bottle detection messages
```

### **Step 2: Test QR Scanner Alone**
```
1. Disconnect from bridge.py
2. Upload qr_arduino.ino to Arduino (COM10)
3. Open Serial Monitor (9600 baud)
4. Scan a QR code
5. You should see:
   - "✓ QR CODE SCAN SUCCESSFUL"
   - "SESSION_START:student_id"
   - LED blinks and buzzer beeps
```

### **Step 3: Check Bridge Communication**
When running `bridge.py`, you should see:
```
✅ Firebase initialized successfully
✅ QR Scanner: COM10
✅ Bottle Sensor: COM4
🚀 Bridge running...
```

**If stuck here with no messages:**
- QR Scanner isn't sending data
- Try scanning a QR code
- Check QR scanner wiring and power

---

## Common Issues & Fixes

### Issue: "No data from QR Scanner"
**Fix:**
- Check COM10 is correct
- Ensure QR scanner is powered (USB or 5V)
- Verify QR scanner TX → Arduino Pin 10
- Try scanning different QR codes

### Issue: "Bottle Sensor not responding"
**Fix:**
- Check COM4 is correct
- Verify ultrasonic sensor wiring:
  - Trig → Pin 10
  - Echo → Pin 11
  - VCC → 5V
  - GND → GND
- Test distance: 7-12cm is valid range

### Issue: "LCD backlight works but no text"
**Fix:**
- Wrong I2C address (see Problem 1)
- Adjust contrast potentiometer
- Check SDA/SCL connections

### Issue: "Bridge connects but nothing happens"
**Fix:**
1. Scan a QR code first
2. Check both Arduino Serial Monitors for debug messages
3. Verify bridge.py is reading data:
   ```python
   # Add this debug line in bridge.py after line 103:
   print(f"DEBUG: Raw QR data: {line}")
   ```

---

## Quick Test Command

**Test Manual Data Flow:**
```
1. Stop bridge.py
2. Open Serial Monitor for Bottle Sensor (COM4)
3. Type: STUDENT:TESTUSER
4. Press Enter
5. LCD should update
6. Wave hand near sensor
7. Should detect bottles
```

If this works, the sensor is fine - issue is with bridge communication.

---

## Hardware Checklist

### LCD I2C Module:
- [ ] SDA → Arduino A4 (or SDA pin)
- [ ] SCL → Arduino A5 (or SCL pin)
- [ ] VCC → 5V
- [ ] GND → GND
- [ ] Contrast adjusted (blue potentiometer)
- [ ] Backlight on

### Ultrasonic Sensor:
- [ ] Trig → Pin 10
- [ ] Echo → Pin 11
- [ ] VCC → 5V
- [ ] GND → GND

### QR Scanner:
- [ ] TX → Arduino Pin 10
- [ ] RX → Arduino Pin 11
- [ ] VCC → 5V or USB
- [ ] GND → GND

---

## Next Steps

1. **Upload `test_lcd_address.ino`** → Find correct LCD address
2. **Test components individually** → Identify which part fails
3. **Check wiring** → Verify all connections
4. **Run bridge.py with debug** → See data flow

Need more help? Check:
- `QUICK_START.md`
- `TROUBLESHOOTING_LCD.md`
- `TEST_SERIAL.md`
