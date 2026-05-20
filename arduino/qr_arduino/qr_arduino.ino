/*
 * ============================================================
 *  T2T - QR ARDUINO (Arduino #2)
 *  COM12 (CH340)
 * ============================================================
 *  RESPONSIBILITIES:
 *    • MH-ET Live QR/barcode scanner  (pin 3 SoftwareSerial RX)
 *    • IR obstacle avoidance sensor   (pin 5, active-LOW)
 *    • Capacitive touch sensor        (pin A0 analog read)
 *      – Detects material: PET plastic / Glass / Metal
 *      – PET  : low capacitance reading (plastic is a poor conductor)
 *      – Glass: medium capacitance reading
 *      – Metal: high capacitance reading (conductor charges sensor)
 *    • Buzzer                         (pin 6)
 *
 *  PROTOCOL  (this Arduino → bridge.py via USB COM12)
 *  QR:<uid>             student QR code scanned
 *  HEARTBEAT            alive pulse every 3 s
 *  IR:ALERT             obstacle held for 2 s
 *  IR:CLEAR             obstacle removed
 *  MATERIAL:PET         capacitive scan → PET bottle  (accepted)
 *  MATERIAL:GLASS       capacitive scan → glass bottle (rejected)
 *  MATERIAL:METAL       capacitive scan → metal can    (rejected)
 *  SCAN_READY           capacitive scan triggered, result following
 *
 *  PROTOCOL  (bridge.py → this Arduino)
 *  SCAN_MATERIAL        bridge tells us to read capacitive sensor now
 *
 * ============================================================
 *  WIRING
 *  QR scanner  TX  → pin 2     QR scanner  VCC → 5V   GND → GND
 *  IR sensor   OUT → pin 5     IR sensor   VCC → 5V   GND → GND
 *  Cap sensor  OUT → Opto board IN    Cap sensor VCC → 5V   GND → GND
 *  Opto board  OUT → pin 3            Opto board VCC → 5V   G   → Arduino GND
 *  Buzzer      +   → pin 6     Buzzer      -   → GND
 * ============================================================
 */

#include <SoftwareSerial.h>

// ===== PINS =====
#define QR_RX        2    // QR scanner TX  → Arduino pin 2
#define QR_TX        4    // unused
#define QR_BAUD      9600  // GM65 default baud rate

#define IR_PIN       5    // active-LOW: LOW = obstacle
#define BUZZER_PIN   6
#define CAP_PIN      3    // Optocoupler isolation board V1 output
                       // Sensor triggers → optocoupler LED ON → NPN conducts → pin pulled LOW
                       // Idle (no object / PET) : pin HIGH (INPUT_PULLUP holds it)
                       // Glass / Metal detected  : pin LOW  (optocoupler NPN sinks it)

// ===== COUNT-BASED THRESHOLDS =====
// We sample digitalRead 100 times over 500 ms and count how many = LOW.
//   PET  (sensor not triggered)    : 0–2   LOW out of 100  ( 0–2%)
//   GLASS (partial/weak trigger)   : 3–20  LOW out of 100  ( 3–20%)
//   METAL (solid trigger)          : 21–100 LOW out of 100 (21–100%)
// TIP: If glass reads the same as metal (both 40+/100), turn the sensitivity
//      pot slightly DOWN until glass only triggers intermittently.
// TIP: If metal still reads <21, turn the sensitivity pot UP.
#define CAP_COUNT_TOTAL      100   // 100 samples over 500ms — catches weak signals
#define CAP_COUNT_PET_MAX      1   // 0-1   LOW → PET  (noise floor; was 2, lowered for sensitivity)
#define CAP_COUNT_GLASS_MAX   20   // 2-20  LOW → GLASS,  21+ → METAL

// ===== TIMING =====
#define IR_ALERT_DURATION_MS  2000   // obstacle must be present for 2 s
#define SCAN_COOLDOWN_MS      3000   // same QR ignored within 3 s

// ===== OBJECTS =====
SoftwareSerial qrSerial(QR_RX, QR_TX);

// ===== QR STATE — char[] instead of String to keep data off the heap =====
#define ID_BUF_LEN 50
char          scannedID[ID_BUF_LEN];
uint8_t       scannedIDLen  = 0;
unsigned long lastCharTime  = 0;
unsigned long lastHeartbeat = 0;
char          lastSentID[ID_BUF_LEN];
unsigned long lastSentTime  = 0;

// ===== IR STATE =====
bool          irObstacle    = false;
bool          irAlertActive = false;
unsigned long irDetectStart = 0;
bool          buzzerOn      = false;

// ===== CAPACITIVE STATE =====
bool          scanPending   = false;  // bridge asked us to scan material
unsigned long lastCapPrint  = 0;      // for state-change check interval
unsigned long lastCapDiag   = 0;      // for periodic raw-pin diagnostic every 2s
bool          lastCapState  = false;  // tracks last triggered/clear state for change log

// ===================================================
//  SETUP
// ===================================================
void setup() {
  Serial.begin(9600);          // USB → bridge.py
  Serial.setTimeout(50);        // prevent readStringUntil blocking for 1000ms

  qrSerial.begin(QR_BAUD);
  qrSerial.listen();
  pinMode(QR_RX, INPUT);   // explicit - no pullup so the scanner drives the line

  pinMode(IR_PIN,     INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  // INPUT_PULLUP + digitalRead is the correct way to read a NPN open-collector sensor.
  // (analogRead ignores INPUT_PULLUP on AVR — that is why old code always returned PET)
  pinMode(CAP_PIN,    INPUT_PULLUP);  // Pullup holds HIGH; optocoupler pulls LOW when triggered

  digitalWrite(BUZZER_PIN, LOW);
  memset(scannedID,  0, ID_BUF_LEN);
  memset(lastSentID, 0, ID_BUF_LEN);

  // Startup cap-sensor check
  Serial.print(F("[CAP] Startup pin: "));
  Serial.println(digitalRead(CAP_PIN) == LOW ? F("LOW (clear sensor area!)") : F("HIGH OK"));

  // 10-second pin-2 diagnostic
  Serial.println(F("[DIAG] Monitoring pin 2 for 10s — scan now..."));
  bool lastState = digitalRead(QR_RX);
  unsigned long diagStart = millis();
  int transitions = 0;
  while (millis() - diagStart < 10000) {
    bool state = digitalRead(QR_RX);
    if (state != lastState) {
      transitions++;
      Serial.print(F("[DIAG] pin2="));
      Serial.println(state ? F("H") : F("L"));
      lastState = state;
    }
  }
  Serial.print(F("[DIAG] Transitions: "));
  Serial.println(transitions);
  if (transitions == 0) {
    Serial.println(F("[DIAG] STUCK — check wiring or switch scanner to UART mode"));
  } else {
    Serial.println(F("[DIAG] Signal OK"));
  }
  Serial.println(F("READY"));
}

// ===================================================
//  MAIN LOOP
// ===================================================
void loop() {
  if (millis() - lastHeartbeat >= 3000) {
    Serial.println(F("HEARTBEAT"));
    lastHeartbeat = millis();
  }

  readQRScanner();
  handleIRSensor();
  readBridge();

  // ── Metal sensor state-change log (majority vote of 5 samples) ──────────
  if (millis() - lastCapPrint >= 200) {
    int votes = 0;
    for (int i = 0; i < 5; i++) { if (digitalRead(CAP_PIN) == LOW) votes++; delay(1); }
    bool triggered = (votes >= 3);   // 3-of-5 majority to avoid single-read noise
    if (triggered != lastCapState) {
      lastCapState = triggered;
      if (triggered) {
        Serial.print(F("[METAL] >>> DETECTED (votes=")); Serial.print(votes); Serial.println(F("/5)"));
      } else {
        Serial.println(F("[METAL] --- cleared"));
      }
    }
    lastCapPrint = millis();
  }

  // ── Periodic raw-pin diagnostic every 2 s (always visible) ─────────────
  if (millis() - lastCapDiag >= 2000) {
    int rawLow = 0;
    for (int i = 0; i < 10; i++) { if (digitalRead(CAP_PIN) == LOW) rawLow++; delay(1); }
    Serial.print(F("[METAL-RAW] pin")); Serial.print(CAP_PIN);
    Serial.print(F("=")); Serial.print(digitalRead(CAP_PIN) == LOW ? F("LOW") : F("HIGH"));
    Serial.print(F("  LOW/10=")); Serial.print(rawLow);
    Serial.println(rawLow >= 5 ? F(" *** TRIGGERED ***") : F(" (clear)"));
    lastCapDiag = millis();
  }
  // ─────────────────────────────────────────────────────

  if (scanPending) {
    scanPending = false;
    performMaterialScan();
  }

  delay(10);
}

// ===================================================
//  READ COMMANDS FROM BRIDGE
// ===================================================
void readBridge() {
  if (!Serial.available()) return;
  // Fixed char buffer — avoids heap allocation from String
  char lineBuf[20];
  uint8_t len = Serial.readBytesUntil('\n', lineBuf, sizeof(lineBuf) - 1);
  lineBuf[len] = '\0';
  if (len > 0 && lineBuf[len - 1] == '\r') lineBuf[--len] = '\0';

  if (strcmp(lineBuf, "SCAN_MATERIAL") == 0) {
    scanPending = true;
  } else if (strcmp(lineBuf, "TEST_CAP") == 0) {
    Serial.println(F("[CAP] Manual test..."));
    performMaterialScan();
  } else if (strcmp(lineBuf, "TEST_METAL") == 0) {
    Serial.print(F("[METAL-DIAG] pin ")); Serial.print(CAP_PIN); Serial.println(F(" x20:"));
    int lowCount = 0;
    for (int i = 0; i < 20; i++) {
      bool s = (digitalRead(CAP_PIN) == LOW);
      if (s) lowCount++;
      Serial.print(s ? 'L' : 'H');
      delay(10);
    }
    Serial.println();
    Serial.print(F("[METAL-DIAG] LOW=")); Serial.print(lowCount); Serial.println(F("/20"));
    if (lowCount >= 10)     Serial.println(F("[METAL-DIAG] TRIGGERED"));
    else if (lowCount >= 2) Serial.println(F("[METAL-DIAG] WEAK — turn sensitivity pot UP"));
    else                    Serial.println(F("[METAL-DIAG] NOT triggered"));
  }
}

// ===================================================
//  QR SCANNER
// ===================================================
void sendQR(const char* id) {
  unsigned long now = millis();
  if (strcmp(id, lastSentID) == 0 && (now - lastSentTime) < SCAN_COOLDOWN_MS) {
    Serial.print(F("[QR] Dup: ")); Serial.println(id);
    return;
  }
  strncpy(lastSentID, id, ID_BUF_LEN - 1);
  lastSentID[ID_BUF_LEN - 1] = '\0';
  lastSentTime = now;
  Serial.print(F("QR:")); Serial.println(id);
}

void readQRScanner() {
  while (qrSerial.available()) {
    char c = qrSerial.read();
    lastCharTime = millis();

    if (c == '\r' || c == '\n') {
      // trim trailing spaces
      while (scannedIDLen > 0 && scannedID[scannedIDLen - 1] == ' ') scannedIDLen--;
      scannedID[scannedIDLen] = '\0';
      if (scannedIDLen >= 1) {
        sendQR(scannedID);
      } else {
        Serial.println(F("[QR] Empty buffer"));
      }
      scannedIDLen = 0;
      scannedID[0] = '\0';
      return;
    }
    if (c >= 32 && c <= 126 && scannedIDLen < ID_BUF_LEN - 1) {
      scannedID[scannedIDLen++] = c;
    }
  }

  // Flush after 400 ms silence (no terminator received)
  if (scannedIDLen >= 1 && millis() - lastCharTime > 400) {
    while (scannedIDLen > 0 && scannedID[scannedIDLen - 1] == ' ') scannedIDLen--;
    scannedID[scannedIDLen] = '\0';
    Serial.print(F("[QR] Flush: ")); Serial.println(scannedID);
    sendQR(scannedID);
    scannedIDLen = 0;
    scannedID[0] = '\0';
    lastCharTime = 0;
  }
}

// ===================================================
//  IR OBSTACLE SENSOR  (active-LOW)
// ===================================================
void handleIRSensor() {
  bool detected = (digitalRead(IR_PIN) == LOW);

  if (detected) {
    if (!irObstacle) {
      irObstacle    = true;
      irDetectStart = millis();
    } else if (!irAlertActive &&
               (millis() - irDetectStart >= IR_ALERT_DURATION_MS)) {
      irAlertActive = true;
      Serial.println(F("IR:ALERT"));
    }
  } else {
    if (irObstacle) {
      irObstacle    = false;
      irAlertActive = false;
      irDetectStart = 0;
      buzzerOn      = false;
      digitalWrite(BUZZER_PIN, LOW);
      Serial.println(F("IR:CLEAR"));
    }
  }

  runBuzzer();
}

void runBuzzer() {
  if (irAlertActive) {
    if (!buzzerOn) { buzzerOn = true;  digitalWrite(BUZZER_PIN, HIGH); }
  } else {
    if (buzzerOn)  { buzzerOn = false; digitalWrite(BUZZER_PIN, LOW);  }
  }
}

// ===================================================
//  CAPACITIVE MATERIAL DETECTION  (digital sampling)
// ===================================================
/*
  iLJCI8A3-B-Z/BY is an NPN NO digital sensor — its output goes LOW when
  an object is detected.  We use digitalRead(INPUT_PULLUP) which is reliable.
  analogRead() IGNORES INPUT_PULLUP on AVR Arduino — that is why previous
  versions always reported PET (the pin floated near 0, delta ≈ 0 always).

  GLASS vs METAL differentiation:
  We take CAP_COUNT_TOTAL samples over 200 ms and count how many are LOW.
  Metal (conductor) holds the output solidly LOW → high count.
  Glass (dielectric) triggers less firmly → lower count near the threshold.
  If glass always reads 40/40 (same as metal), reduce the sensor
  sensitivity pot slightly until glass triggers intermittently.

  COUNT thresholds (adjust if needed):
    0  – CAP_COUNT_PET_MAX   → PET   (not triggered)
    +1 – CAP_COUNT_GLASS_MAX → GLASS (partially triggered)
    +1 – CAP_COUNT_TOTAL     → METAL (solidly triggered)
*/
int readCapDigital() {
  // Returns count of LOW readings out of CAP_COUNT_TOTAL (40 × 5 ms = 200 ms).
  // A 200 ms pause is acceptable here because this function is only called
  // after SCAN_MATERIAL is received — QR data has already been processed.
  int countLow = 0;
  for (int i = 0; i < CAP_COUNT_TOTAL; i++) {
    if (digitalRead(CAP_PIN) == LOW) countLow++;  // INPUT_PULLUP: LOW = optocoupler triggered
    delay(5);
  }
  return countLow;
}

void performMaterialScan() {
  Serial.println(F("SCAN_READY"));
  Serial.print(F("[CAP] Pre-scan: "));
  Serial.println(lastCapState ? F("TRIGGERED") : F("CLEAR"));

  delay(200);

  int countLow = readCapDigital();

  if (countLow == 0 && lastCapState) {
    Serial.println(F("[CAP] Fallback: live TRIGGERED -> GLASS"));
    countLow = CAP_COUNT_PET_MAX + 1;
  }

  Serial.print(F("[CAP] LOW=")); Serial.print(countLow);
  Serial.print(F("/")); Serial.println(CAP_COUNT_TOTAL);

  if (countLow <= CAP_COUNT_PET_MAX) {
    Serial.println(F("[CAP] PET -> ACCEPTED"));
    Serial.println(F("MATERIAL:PET"));
    tone(BUZZER_PIN, 2500, 150);
  } else if (countLow <= CAP_COUNT_GLASS_MAX) {
    Serial.println(F("[CAP] GLASS -> REJECTED"));
    Serial.println(F("MATERIAL:GLASS"));
    tone(BUZZER_PIN, 800, 400);
  } else {
    Serial.println(F("[CAP] METAL -> REJECTED"));
    Serial.println(F("MATERIAL:METAL"));
    tone(BUZZER_PIN, 400, 600);
  }
}