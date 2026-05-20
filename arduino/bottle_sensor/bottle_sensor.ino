/*
 * ============================================================
 *  T2T - BOTTLE SENSOR ARDUINO (Arduino #1)
 *  COM4 (FTDI)
 * ============================================================
 *  RESPONSIBILITIES:
 *    • 1602 I2C LCD display
 *    • HC-SR04 Ultrasonic sensor  (bottle presence detection)
 *    • Servo motor                (bottle gate — pin 9)
 *    • Buzzer  (audio feedback)
 *    • HardwareSerial (USB / COM4): talk to bridge.py
 *
 *  WHAT THIS ARDUINO DOES NOT DO:
 *    • No QR     — QR is on qr_arduino
 *    • No IR / capacitive — those are on qr_arduino
 *
 *  PROTOCOL  (bridge.py ↔ this Arduino)
 *  <- STUDENT:<name>:<studentID>   start session, show welcome
 *  <- ERROR:notfound               show error on LCDs
 *  <- ACCEPTED                     bridge confirmed PET — play accept tone, update count
 *  <- REJECTED:<reason>            bridge rejected (GLASS/METAL) — play reject tone, show reason
 *  <- OBSTACLE:1 / OBSTACLE:0      IR alert from qr_arduino relayed by bridge
 *  -> BOTTLE_DETECTED:<studentID>  bottle present on leading edge — bridge decides accept/reject
 *  -> SESSION_START:<studentID>
 *  -> SESSION_END:<studentID>
 * ============================================================
 */

#include <LiquidCrystal_I2C.h>
#include <Servo.h>

// ===== PIN CONFIGURATION =====
#define LCD_ADDR        0x27   // 0x27 if this doesn't work
#define LCD_COLS        16
#define LCD_ROWS        2

#define BUZZER_PIN      8
#define SERVO_PIN       9
#define ULTRASONIC_TRIG 7
#define ULTRASONIC_ECHO 6

#define MIN_BOTTLE_CM   3
#define MAX_BOTTLE_CM   30

#define SERVO_OPEN_ANGLE  90   // degrees when gate is open (PET accepted)
#define SERVO_CLOSE_ANGLE  0   // degrees when gate is closed
#define GATE_OPEN_MS    3000   // ms gate stays open before auto-close

// ===== TIMING =====
#define SESSION_TIMEOUT  45000UL  // 45 s idle → auto logout
#define MAX_BOTTLES      10       // max bottles per session
#define BOTTLE_COOLDOWN  2500UL   // ms to wait before detecting next bottle

// ===== OBJECTS =====
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);
Servo             gateServo;

// ===== STATE =====
String        studentID        = "";
String        studentName      = "";
bool          sessionActive    = false;
int           bottleCount      = 0;
unsigned long lastActivity     = 0;
unsigned long lastBottleTime   = 0;
bool          bottleWasPresent = false;
bool          obstacleBlocked  = false;
bool          waitingForResult  = false;  // true after BOTTLE_DETECTED sent, waiting for ACCEPTED/REJECTED
bool          pendingEndSession = false;  // endSession() will be called after screen hold
bool          gateOpen         = false;  // current servo state
unsigned long gateOpenedAt     = 0;      // millis() when gate was opened
unsigned long screenRevertAt    = 0;     // millis() when to switch away from temp screen (0 = none)
unsigned long sessionGraceUntil = 0;     // no scanning before this time after session start
unsigned long lastDebugPrint    = 0;

// ===================================================
//  SETUP
// ===================================================
void setup() {
  Serial.begin(9600);
  Serial.setTimeout(50);   // 50 ms is enough for a 9600-baud \n-terminated message

  lcd.init();
  lcd.backlight();
  delay(200);        // let I2C LCD settle before first write
  showSplashScreen();
  showIdleScreen();

  gateServo.attach(SERVO_PIN);
  gateServo.write(SERVO_CLOSE_ANGLE);   // gate closed at startup
  gateOpen = false;

  pinMode(BUZZER_PIN,      OUTPUT);
  pinMode(ULTRASONIC_TRIG, OUTPUT);
  pinMode(ULTRASONIC_ECHO, INPUT);

  // Startup beep
  beep(100);
  delay(100);
  beep(100);

  Serial.println("READY");
}

// ===================================================
//  MAIN LOOP
// ===================================================
void loop() {
  readBridge();

  // ── Non-blocking screen revert ──────────────────────────
  if (screenRevertAt > 0 && millis() >= screenRevertAt) {
    screenRevertAt = 0;
    if (pendingEndSession) {
      pendingEndSession = false;
      endSession();
    } else if (sessionActive) {
      showWelcomeScreen();
    } else {
      showIdleScreen();
    }
  }

  // ── Auto-close gate after GATE_OPEN_MS ────────────────
  if (gateOpen && (millis() - gateOpenedAt >= GATE_OPEN_MS)) {
    gateServo.write(SERVO_CLOSE_ANGLE);
    gateOpen = false;
  }

  if (sessionActive) {
    checkSessionTimeout();
    if (!obstacleBlocked && !waitingForResult && !gateOpen) {
      checkBottle();
    }
  }

  // Distance debug every 500 ms
  if (millis() - lastDebugPrint >= 500) {
    float d = measureDistance();
    Serial.print("[DIST] ");
    Serial.print(d);
    Serial.print(" cm | session:");
    Serial.print(sessionActive ? "Y" : "N");
    Serial.print(" | blocked:");
    Serial.println(obstacleBlocked ? "Y" : "N");
    lastDebugPrint = millis();
  }

  delay(10);   // small yield — keeps loop responsive without blocking serial
}

// ===================================================
//  LCD HELPERS
// ===================================================

// ===================================================
//  BUZZER HELPER
//  Works for ACTIVE buzzers (common cheap buzzers that
//  buzz at fixed pitch when powered HIGH).
//  tone() conflicts with Servo.h on some boards — this
//  approach is always reliable.
// ===================================================
void beep(int durationMs) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(durationMs);
  digitalWrite(BUZZER_PIN, LOW);
}

void beepTwice(int onMs, int gapMs) {
  beep(onMs);
  delay(gapMs);
  beep(onMs);
}
void lcdLine(uint8_t row, String text) {
  while ((int)text.length() < LCD_COLS) text += ' ';
  text = text.substring(0, LCD_COLS);
  lcd.setCursor(0, row);
  lcd.print(text);
}

void showSplashScreen() {
  lcd.clear();
  lcdLine(0, "  Welcome to");
  lcdLine(1, "   T2T Bottle");
  delay(1500);
  lcd.clear();
  lcdLine(0, "  Recycling");
  lcdLine(1, "   Station!");
  delay(1500);
}

void showIdleScreen() {
  lcd.clear();
  lcdLine(0, "Scan QR to");
  lcdLine(1, "Start");
}

void showWelcomeScreen() {
  lcd.clear();
  lcdLine(0, "Hello " + studentName);
  lcdLine(1, "Insert bottle...");
}

void showScanningScreen() {
  lcd.clear();
  lcdLine(0, "Scanning...");
  lcdLine(1, "Please wait");
}

void showAcceptedScreen() {
  lcd.clear();
  lcdLine(0, "Accepted! PET :)");
  lcdLine(1, "Bottles: " + String(bottleCount));
}

void showRejectedScreen(String reason) {
  lcd.clear();
  lcdLine(0, "Rejected object!");
  lcdLine(1, "PET bottles only");
}

void showSessionEndScreen() {
  lcd.clear();
  lcdLine(0, "Session Ended");
  lcdLine(1, "Bottles: " + String(bottleCount));
}

void showErrorScreen(String msg) {
  lcd.clear();
  lcdLine(0, "Error!");
  lcdLine(1, msg);
}

// ===================================================
//  READ FROM BRIDGE
// ===================================================
void readBridge() {
  if (!Serial.available()) return;

  String line = Serial.readStringUntil('\n');
  line.trim();

  if (line.startsWith("STUDENT:")) {
    // STUDENT:<name>:<studentID>
    String payload = line.substring(8);
    int sep = payload.lastIndexOf(':');
    if (sep != -1) {
      studentName = payload.substring(0, sep);
      studentID   = payload.substring(sep + 1);
    } else {
      studentName = payload;
      studentID   = payload;
    }
    startSession();

  } else if (line == "ACCEPTED") {
    if (!sessionActive) return;  // session ended before bridge replied
    // Bridge confirmed bottle is PET — open gate
    bottleCount++;
    lastActivity     = millis();
    lastBottleTime   = millis();
    waitingForResult = false;
    gateServo.write(SERVO_OPEN_ANGLE);
    gateOpen     = true;
    gateOpenedAt = millis();
    showAcceptedScreen();
    beep(200);
    if (bottleCount >= MAX_BOTTLES) {
      pendingEndSession = true;
    }
    screenRevertAt = millis() + 2000;

  } else if (line.startsWith("REJECTED:")) {
    if (!sessionActive) return;  // session ended before bridge replied
    // Bridge rejected bottle (not PET) — gate stays closed
    String reason = line.substring(9);
    waitingForResult = false;
    lastBottleTime   = millis();
    gateServo.write(SERVO_CLOSE_ANGLE);   // ensure closed
    gateOpen = false;
    showRejectedScreen(reason);
    beep(400);
    screenRevertAt = millis() + 2500;

  } else if (line == "OBSTACLE:1") {
    obstacleBlocked = true;
    beepTwice(300, 150);
    lcdLine(0, "!! WARNING !!");
    lcdLine(1, "REMOVE OBSTACLE!");

  } else if (line == "OBSTACLE:0") {
    obstacleBlocked = false;
    beep(150);
    if (sessionActive) showWelcomeScreen();
    else               showIdleScreen();

  } else if (line.startsWith("ERROR:")) {
    showErrorScreen("Not Found!");
    beep(500);
    screenRevertAt = millis() + 2000;

  } else if (line == "SESSION_END") {
    endSession();
  }
}

// ===================================================
//  SESSION MANAGEMENT
// ===================================================
void startSession() {
  sessionActive     = true;
  bottleCount       = 0;
  bottleWasPresent  = false;
  waitingForResult  = false;
  pendingEndSession = false;
  screenRevertAt    = 0;    // cancel any pending revert from previous session
  lastActivity      = millis();
  lastBottleTime    = millis();

  sessionGraceUntil = millis() + 3000;   // 3s grace after QR scan
  showWelcomeScreen();
  Serial.println("SESSION_START:" + studentID);
}

void checkSessionTimeout() {
  if (millis() - lastActivity >= SESSION_TIMEOUT) {
    endSession();
  }
}

void endSession() {
  showSessionEndScreen();
  Serial.println("SESSION_END:" + studentID);

  // Ensure gate is closed when session ends
  gateServo.write(SERVO_CLOSE_ANGLE);
  gateOpen = false;

  studentID         = "";
  studentName       = "";
  bottleCount       = 0;
  sessionActive     = false;
  bottleWasPresent  = false;
  waitingForResult  = false;
  pendingEndSession = false;
  sessionGraceUntil = 0;
  lastActivity      = 0;

  // Show end screen for 3 s then revert to idle (non-blocking)
  screenRevertAt = millis() + 3000;
}

// ===================================================
//  ULTRASONIC BOTTLE DETECTION
// ===================================================
float measureDistance() {
  digitalWrite(ULTRASONIC_TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(ULTRASONIC_TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(ULTRASONIC_TRIG, LOW);

  long dur = pulseIn(ULTRASONIC_ECHO, HIGH, 30000UL);
  if (dur == 0) return 999.0;
  return (dur * 0.034f) / 2.0f;
}

bool bottlePresent() {
  float d = measureDistance();
  return (d >= MIN_BOTTLE_CM && d <= MAX_BOTTLE_CM);
}

// Edge-triggered: fires once when bottle first appears
void checkBottle() {
  bool present = bottlePresent();

  if (present && !bottleWasPresent) {
    unsigned long now = millis();
    // Always mark as present to avoid false edge after grace/cooldown expires
    bottleWasPresent = true;
    if (now >= sessionGraceUntil && now - lastBottleTime >= BOTTLE_COOLDOWN) {
      // Notify bridge — bridge will ask qr_arduino for material
      showScanningScreen();
      Serial.println("BOTTLE_DETECTED:" + studentID);
      waitingForResult = true;
      lastActivity     = millis();
    }
  } else if (!present) {
    bottleWasPresent = false;
  }
}