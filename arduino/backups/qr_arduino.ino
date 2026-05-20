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
// We sample digitalRead 40 times over 200 ms and count how many = LOW.
//   PET  (sensor off)             : 0–7  LOW out of 40
//   GLASS (near-threshold trigger) : 8–32 LOW out of 40
//   METAL (solid full trigger)     : 33–40 LOW out of 40
// TIP: If glass is always 40/40 (same as metal), turn the sensitivity
//      pot slightly DOWN until glass only triggers intermittently.
#define CAP_COUNT_TOTAL       40   // total digital samples
#define CAP_COUNT_PET_MAX      7   // 0–7  LOW → PET
#define CAP_COUNT_GLASS_MAX   32   // 8–32 LOW → GLASS,  33+ → METAL

// ===== TIMING =====
#define IR_ALERT_DURATION_MS  2000   // obstacle must be present for 2 s
#define SCAN_COOLDOWN_MS      3000   // same QR ignored within 3 s

// ===== OBJECTS =====
// Normal TTL UART — idle HIGH, start bit LOW.
// If you still see 0xFF, the scanner is in USB-HID mode and
// needs to be switched to UART mode by scanning the config barcode.
SoftwareSerial qrSerial(QR_RX, QR_TX);

// ===== QR STATE =====
String        scannedID    = "";
unsigned long lastCharTime  = 0;
unsigned long lastHeartbeat = 0;
String        lastSentID    = "";
unsigned long lastSentTime  = 0;

// ===== IR STATE =====
bool          irObstacle    = false;
bool          irAlertActive = false;
unsigned long irDetectStart = 0;
bool          buzzerOn      = false;

// ===== CAPACITIVE STATE =====
bool          scanPending   = false;  // bridge asked us to scan material
unsigned long lastCapPrint  = 0;      // for live debug print every 500 ms

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
  pinMode(CAP_PIN,    INPUT_PULLUP);

  digitalWrite(BUZZER_PIN, LOW);

  // ── Quick sensor sanity check ────────────────────────────
  bool startupState = (digitalRead(CAP_PIN) == LOW);
  Serial.print("[CAP] Startup pin state: ");
  Serial.println(startupState ? "LOW (sensor triggered at boot — clear sensor area!)" : "HIGH — sensor clear OK");
  Serial.println("[CAP] Using digital sampling. Watch [CAP-LIVE] in Serial Monitor.");
  // ─────────────────────────────────────────────────────────

  Serial.println("[DIAG] Monitoring pin 2 for 10 seconds — scan now...");
  // Watch: if pin stays always HIGH or always LOW with no change,
  // scanner TX wire is not connected or scanner is in USB-HID mode (silent TX).
  bool lastState = digitalRead(QR_RX);
  unsigned long diagStart = millis();
  int transitions = 0;
  while (millis() - diagStart < 10000) {
    bool state = digitalRead(QR_RX);
    if (state != lastState) {
      transitions++;
      Serial.print("[DIAG] Pin 2 changed to: ");
      Serial.println(state ? "HIGH" : "LOW");
      lastState = state;
    }
  }
  Serial.print("[DIAG] Done. Transitions detected: ");
  Serial.println(transitions);
  if (transitions == 0) {
    Serial.println("[DIAG] Pin 2 is STUCK (no signal). Check:");
    Serial.println("  1. Scanner TX wire physically in Arduino pin 2");
    Serial.println("  2. Scanner GND connected to Arduino GND");
    Serial.println("  3. If scanner is USB-HID mode, scan the UART config barcode");
    Serial.println("     to enable serial TX output");
  } else {
    Serial.println("[DIAG] Pin 2 has signal — SoftwareSerial issue, not wiring");
  }
  Serial.println("[DIAG] Starting normal operation...");
  Serial.println("READY");
}

// ===================================================
//  MAIN LOOP
// ===================================================
void loop() {
  if (millis() - lastHeartbeat >= 3000) {
    Serial.println("HEARTBEAT");
    lastHeartbeat = millis();
  }

  readQRScanner();
  handleIRSensor();
  readBridge();

  // ── Live capacitive monitor (every 500 ms) ───────────
  if (millis() - lastCapPrint >= 500) {
    bool triggered = (digitalRead(CAP_PIN) == LOW);
    Serial.print("[CAP-LIVE] pin=");
    Serial.println(triggered ? "LOW  → triggered (glass/metal)" : "HIGH → clear (PET/empty)");
    lastCapPrint = millis();
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
  String line = Serial.readStringUntil('\n');
  line.trim();
  if (line == "SCAN_MATERIAL") {
    scanPending = true;
  }
}

// ===================================================
//  QR SCANNER
// ===================================================
void sendQR(String id) {
  unsigned long now = millis();
  if (id == lastSentID && (now - lastSentTime) < SCAN_COOLDOWN_MS) {
    Serial.println("[QR] Duplicate ignored (cooldown): " + id);
    return;
  }
  lastSentID   = id;
  lastSentTime = now;
  Serial.println("[QR] Sending: " + id);
  Serial.println("QR:" + id);
}

void readQRScanner() {
  while (qrSerial.available()) {
    char c = qrSerial.read();
    lastCharTime = millis();

    // Raw byte debug — print every byte the QR scanner sends
    // Watch Serial Monitor: if nothing appears here when you scan, the
    // wiring is wrong or baud rate mismatches. Try 115200 if 9600 shows nothing.
    Serial.print("[QR-RAW] 0x");
    if ((uint8_t)c < 0x10) Serial.print("0");
    Serial.print((uint8_t)c, HEX);
    Serial.print(" dec=");
    Serial.print((uint8_t)c);
    Serial.print(" '");
    if (c >= 32 && c <= 126) Serial.print(c);
    else Serial.print('?');
    Serial.println("'");

    if (c == '\r' || c == '\n') {
      scannedID.trim();
      if (scannedID.length() >= 1) {
        sendQR(scannedID);
      } else {
        Serial.println("[QR] Terminator received but buffer empty");
      }
      scannedID = "";
      return;
    }
    if (c >= 32 && c <= 126) scannedID += c;
  }

  // Flush after 400 ms silence (no terminator received)
  if (scannedID.length() >= 1 && millis() - lastCharTime > 400) {
    scannedID.trim();
    Serial.println("[QR] Flush (no terminator, 400ms silence): '" + scannedID + "'");
    sendQR(scannedID);
    scannedID    = "";
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
      Serial.println("IR:ALERT - obstacle detected for 2 s!");
    }
  } else {
    if (irObstacle) {
      irObstacle    = false;
      irAlertActive = false;
      irDetectStart = 0;
      buzzerOn      = false;
      digitalWrite(BUZZER_PIN, LOW);
      Serial.println("IR:CLEAR - obstacle removed.");
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
    if (digitalRead(CAP_PIN) == LOW) countLow++;
    delay(5);
  }
  return countLow;
}

void performMaterialScan() {
  Serial.println("SCAN_READY");

  int countLow = readCapDigital();

  Serial.println("[CAP] ====== Material Scan ======");
  Serial.print("[CAP] LOW count : "); Serial.print(countLow);
  Serial.print(" / "); Serial.println(CAP_COUNT_TOTAL);
  Serial.print("[CAP] Zones     : PET 0-"); Serial.print(CAP_COUNT_PET_MAX);
  Serial.print("  GLASS "); Serial.print(CAP_COUNT_PET_MAX + 1);
  Serial.print("-"); Serial.print(CAP_COUNT_GLASS_MAX);
  Serial.print("  METAL "); Serial.print(CAP_COUNT_GLASS_MAX + 1);
  Serial.print("-"); Serial.println(CAP_COUNT_TOTAL);

  if (countLow <= CAP_COUNT_PET_MAX) {
    Serial.println("[CAP] Result    : PET plastic  ✓ ACCEPTED");
    Serial.println("MATERIAL:PET");
    tone(BUZZER_PIN, 2500, 150);
  } else if (countLow <= CAP_COUNT_GLASS_MAX) {
    Serial.println("[CAP] Result    : GLASS bottle ✗ REJECTED");
    Serial.println("MATERIAL:GLASS");
    tone(BUZZER_PIN, 800, 400);
  } else {
    Serial.println("[CAP] Result    : METAL can    ✗ REJECTED");
    Serial.println("MATERIAL:METAL");
    tone(BUZZER_PIN, 400, 600);
  }
  Serial.println("[CAP] ==========================");
}