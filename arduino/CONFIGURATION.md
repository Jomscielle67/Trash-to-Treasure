# ⚙️ Configuration Reference

## 🔧 Adjustable Settings

### QR Scanner Arduino (qr_arduino.ino)

#### Serial Communication
```cpp
#define SCANNER_RX_PIN 10          // QR Module TX → Arduino Pin 10
#define SCANNER_TX_PIN 11          // QR Module RX → Arduino Pin 11
#define SCANNER_BAUD 9600          // Baud rate (try 19200 if not working)
```

#### Hardware Pins
```cpp
#define LED_SUCCESS_PIN 7          // Green LED (active session indicator)
#define LED_ERROR_PIN 6            // Red LED (error indicator)
#define BUZZER_PIN 8               // Buzzer (audio feedback)
#define BUTTON_PIN 2               // Manual reset button
```

#### Session Settings
```cpp
#define MIN_ID_LENGTH 3            // Minimum student ID length
#define MAX_ID_LENGTH 50           // Maximum student ID length
#define SCAN_TIMEOUT_MS 200        // Wait time for complete QR scan
#define SESSION_TIMEOUT_MS 15000   // 15 seconds = session timeout
                                   // Change to 20000 for 20 seconds
                                   // Change to 30000 for 30 seconds
```

#### Feedback Settings
```cpp
#define SUCCESS_BEEP_MS 100        // Success beep duration
#define ERROR_BEEP_MS 300          // Error beep duration
```

#### Feature Toggles
```cpp
#define ENABLE_LEDS true           // Set false if no LEDs
#define ENABLE_BUZZER true         // Set false if no buzzer
#define ENABLE_BUTTON true         // Set false if no button
#define DEBUG_MODE true            // Set false for production (less output)
```

**💡 Quick Changes:**

**Increase session timeout to 30 seconds:**
```cpp
#define SESSION_TIMEOUT_MS 30000   // 30 seconds
```

**Disable audio for quiet environments:**
```cpp
#define ENABLE_BUZZER false
```

**Production mode (minimal output):**
```cpp
#define DEBUG_MODE false
```

---

### Bottle Sensor Arduino (bottle_sensor.ino)

#### Pins
```cpp
const int trigPin = 10;           // Ultrasonic trigger
const int echoPin = 11;           // Ultrasonic echo
const int buzzerPin = 7;          // Buzzer
const int ledPin = 13;            // LED indicator
const int buttonPin = 2;          // Manual reset button
```

#### Timing
```cpp
const unsigned long debounceMs = 800;  // Debounce time between bottles
                                        // Increase if counting double
                                        // Decrease for faster scanning
```

#### Detection Range
```cpp
// In the loop() function:
bool accepted = (distanceCm >= 7 && distanceCm <= 12);  // Acceptance range
bool detected = (distanceCm >= 2 && distanceCm <= 20);  // Detection range
```

**💡 Adjust bottle acceptance:**

**For larger bottles:**
```cpp
bool accepted = (distanceCm >= 10 && distanceCm <= 15);
```

**For smaller bottles:**
```cpp
bool accepted = (distanceCm >= 5 && distanceCm <= 10);
```

**More permissive (all sizes):**
```cpp
bool accepted = (distanceCm >= 5 && distanceCm <= 20);
```

#### LCD Address
```cpp
LiquidCrystal_I2C lcd(0x27, 16, 2);  // Address 0x27, 16x2 display
                                      // Try 0x3F if 0x27 doesn't work
```

**💡 If LCD not working, scan for address:**
```cpp
// Upload I2C Scanner sketch to find your LCD address
// Common addresses: 0x27, 0x3F
```

---

### Python Bridge (bridge.py)

#### Serial Ports
```python
BAUD = 9600                        # Baud rate (must match Arduino)
QR_SCANNER_PORT = "COM4"           # QR Scanner Arduino port
BOTTLE_SENSOR_PORT = "COM3"        # Bottle Sensor Arduino port
```

**💡 Find your COM ports:**
```bash
# Windows:
python -m serial.tools.list_ports

# Or check Device Manager → Ports (COM & LPT)
```

#### Firebase Configuration
```python
FIREBASE_KEY_PATH = "../../serviceAccountKey.json"  # Relative path
BACKUP_FILE = "unsent_data.json"                    # Local backup
RETRY_INTERVAL = 10                                 # Retry every 10 seconds
```

**💡 Adjust paths:**

**If key is in same folder:**
```python
FIREBASE_KEY_PATH = "serviceAccountKey.json"
```

**If key is in parent folder:**
```python
FIREBASE_KEY_PATH = "../serviceAccountKey.json"
```

**Absolute path:**
```python
FIREBASE_KEY_PATH = "C:/Users/Vincent/Desktop/capstone/t2t/Super_User/serviceAccountKey.json"
```

#### Points Calculation
```python
# In update_student_points() function:
new_points = current_points + bottles_to_add  # 1 bottle = 1 point
```

**💡 Change point value:**

**2 points per bottle:**
```python
new_points = current_points + (bottles_to_add * 2)
```

**Custom formula:**
```python
# 1st bottle = 1 point, 2nd = 2 points, 3rd = 3 points, etc.
points_earned = sum(range(1, bottles_to_add + 1))
new_points = current_points + points_earned
```

---

## 🎯 Common Configuration Scenarios

### Scenario 1: Quiet Environment (No Sound)
```cpp
// qr_arduino.ino
#define ENABLE_BUZZER false

// bottle_sensor.ino
// Comment out all tone() calls or set buzzerPin to -1
```

### Scenario 2: Longer Session Timeout (30 seconds)
```cpp
// qr_arduino.ino
#define SESSION_TIMEOUT_MS 30000  // 30 seconds
```

### Scenario 3: Accept All Bottle Sizes
```cpp
// bottle_sensor.ino
bool accepted = (distanceCm >= 2 && distanceCm <= 20);
```

### Scenario 4: Different COM Ports
```python
# bridge.py
QR_SCANNER_PORT = "COM5"      # Your actual port
BOTTLE_SENSOR_PORT = "COM6"   # Your actual port
```

### Scenario 5: Higher Baud Rate (Faster)
```cpp
// qr_arduino.ino
#define SCANNER_BAUD 19200

// bottle_sensor.ino
Serial.begin(19200);

// bridge.py
BAUD = 19200
```

### Scenario 6: More Points Per Bottle
```python
# bridge.py - update_student_points()
POINTS_PER_BOTTLE = 5
new_points = current_points + (bottles_to_add * POINTS_PER_BOTTLE)
```

### Scenario 7: Production Mode (Minimal Logging)
```cpp
// qr_arduino.ino
#define DEBUG_MODE false

// bottle_sensor.ino
// Comment out Serial.println() debug statements

// bridge.py
# Add logging level control
import logging
logging.basicConfig(level=logging.WARNING)  # Only show warnings/errors
```

---

## 🔍 Diagnostic Settings

### Enable Maximum Debug Output

**qr_arduino.ino:**
```cpp
#define DEBUG_MODE true
```

**bottle_sensor.ino:**
```cpp
// Keep all Serial.println() statements uncommented
```

**bridge.py:**
```python
# Add verbose logging
print(f"[DEBUG] Received: {line}")  # Add throughout
```

---

## 📊 Performance Tuning

### Optimize for Speed
```cpp
// qr_arduino.ino
#define SCAN_TIMEOUT_MS 100        // Faster QR reading

// bottle_sensor.ino
const unsigned long debounceMs = 500;  // Faster bottle counting
```

### Optimize for Accuracy
```cpp
// qr_arduino.ino
#define SCAN_TIMEOUT_MS 300        // More time for QR reading

// bottle_sensor.ino
const unsigned long debounceMs = 1000;  // Prevent double counting
```

---

## 🌐 Firebase Configuration

### Collection Name
```python
# bridge.py - update_student_points()
students_ref = db.collection('students')  # Collection name
```

**💡 Use different collection:**
```python
students_ref = db.collection('users')  # Or any other name
```

### Query Field
```python
# bridge.py
query = students_ref.where('studentID', '==', student_id)
```

**💡 Query by different field:**
```python
query = students_ref.where('email', '==', student_email)
```

### Update Fields
```python
# bridge.py
student_doc.reference.update({
    'points': new_points,
    'bottles': new_bottles,
    'lastUpdated': firestore.SERVER_TIMESTAMP
})
```

**💡 Add more fields:**
```python
student_doc.reference.update({
    'points': new_points,
    'bottles': new_bottles,
    'lastUpdated': firestore.SERVER_TIMESTAMP,
    'lastBottleTime': firestore.SERVER_TIMESTAMP,
    'totalSessions': current_sessions + 1
})
```

---

## 🔐 Security Settings

### Firebase Rules (Firestore)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /students/{studentId} {
      // Allow reads for authenticated users
      allow read: if request.auth != null;
      
      // Allow writes only from admin
      allow write: if request.auth != null && 
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }
  }
}
```

---

## 📝 Configuration Checklist

Before running the system, verify:

- [ ] **qr_arduino.ino** - Correct pins, baud rate, session timeout
- [ ] **bottle_sensor.ino** - Correct pins, bottle range, LCD address
- [ ] **bridge.py** - Correct COM ports, Firebase key path
- [ ] **Firebase** - Service account key downloaded and placed
- [ ] **Arduino** - Both sketches uploaded successfully
- [ ] **Hardware** - All connections secure and tested
- [ ] **Serial Monitors** - Can see output from both Arduinos
- [ ] **Bridge** - Connects to both COM ports successfully

---

## 🛠️ Quick Settings Reference

| Setting | File | Default | Purpose |
|---------|------|---------|---------|
| Session Timeout | qr_arduino.ino | 15000ms | How long before auto-reset |
| Bottle Range | bottle_sensor.ino | 7-12cm | Valid bottle distance |
| Debounce Time | bottle_sensor.ino | 800ms | Prevent double counts |
| Baud Rate | All files | 9600 | Serial communication speed |
| QR Port | bridge.py | COM4 | QR Scanner Arduino port |
| Bottle Port | bridge.py | COM3 | Bottle Sensor Arduino port |
| Points/Bottle | bridge.py | 1 | Points earned per bottle |
| Retry Interval | bridge.py | 10s | Firebase retry frequency |

---

**Last Updated:** October 16, 2025  
**Configuration Guide for T2T System v4.0**
