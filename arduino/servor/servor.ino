/*
 * ============================================================
 *  T2T - SERVO ARDUINO (Arduino #3)
 *  COM port auto-detected by bridge.py (CH341 or second FTDI)
 * ============================================================
 *  RESPONSIBILITY:
 *    • SG90 / MG995 servo motor — bottle gate
 *    • Receives commands from bridge.py over USB HardwareSerial
 *    • Sends back status so bridge can confirm gate state
 *
 *  PROTOCOL  (bridge.py → this Arduino)
 *  OPEN             open the gate (servo → OPEN_ANGLE)
 *  CLOSE            close the gate (servo → CLOSE_ANGLE)
 *
 *  PROTOCOL  (this Arduino → bridge.py)
 *  READY            startup confirmation
 *  SERVO_OPENED     gate finished opening
 *  SERVO_CLOSED     gate finished closing
 *
 *  WIRING
 *    Servo signal → pin 9    (PWM)
 *    Servo VCC    → 5 V (use external supply for MG995)
 *    Servo GND    → GND (shared with Arduino GND)
 * ============================================================
 */

#include <Servo.h>

// ===== CONFIGURATION =====
#define SERVO_PIN    9
#define OPEN_ANGLE   90    // degrees — gate open   (adjust to your build)
#define CLOSE_ANGLE   0    // degrees — gate closed (adjust to your build)
#define SWEEP_DELAY  15    // ms between each 1° step (smooth movement)

Servo gateServo;
int   currentAngle = CLOSE_ANGLE;   // manual tracking — gateServo.read() is unreliable before first write

// ===================================================
//  SETUP
// ===================================================
void setup() {
  Serial.begin(9600);
  Serial.setTimeout(100);

  gateServo.attach(SERVO_PIN);
  gateServo.write(CLOSE_ANGLE);   // force physical position immediately
  currentAngle = CLOSE_ANGLE;
  delay(800);                      // wait for servo to physically reach closed position

  Serial.println("READY");
}

// ===================================================
//  MAIN LOOP
// ===================================================
void loop() {
  if (!Serial.available()) return;

  String cmd = Serial.readStringUntil('\n');
  cmd.trim();

  if (cmd == "OPEN") {
    sweepTo(OPEN_ANGLE);
    Serial.println("SERVO_OPENED");   // always confirm so bridge knows gate state

  } else if (cmd == "CLOSE") {
    sweepTo(CLOSE_ANGLE);
    Serial.println("SERVO_CLOSED");   // always confirm
  }
}

// ===================================================
//  SMOOTH SWEEP
//  Moves one degree at a time so the gate doesn't slam.
// ===================================================
void sweepTo(int targetAngle) {
  if (currentAngle == targetAngle) return;
  int step = (targetAngle > currentAngle) ? 1 : -1;
  while (currentAngle != targetAngle) {
    currentAngle += step;
    gateServo.write(currentAngle);
    delay(SWEEP_DELAY);
  }
}
