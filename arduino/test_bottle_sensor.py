"""
Quick Test Script for Bottle Sensor LCD
========================================
This script tests if the Bottle Sensor Arduino can receive commands
and update the LCD display.
"""

import serial
import time
import sys

# =========================
# CONFIGURATION
# =========================
BOTTLE_SENSOR_PORT = "COM3"  # Change to your bottle sensor port
BAUD = 9600

print("\n" + "="*60)
print("🧪 BOTTLE SENSOR LCD TEST")
print("="*60 + "\n")

# =========================
# CONNECT TO ARDUINO
# =========================
print(f"📡 Connecting to {BOTTLE_SENSOR_PORT} at {BAUD} baud...")
try:
    ser = serial.Serial(BOTTLE_SENSOR_PORT, BAUD, timeout=1)
    print(f"✅ Connected successfully!\n")
except Exception as e:
    print(f"❌ Connection failed: {e}")
    print(f"\nTroubleshooting:")
    print(f"  1. Check if {BOTTLE_SENSOR_PORT} is correct")
    print(f"  2. Close Arduino IDE Serial Monitor")
    print(f"  3. Check Device Manager for correct port")
    input("\nPress Enter to exit...")
    sys.exit(1)

# Wait for Arduino to reset after serial connection
print("⏳ Waiting for Arduino to initialize (2 seconds)...\n")
time.sleep(2)

# Clear any startup messages
while ser.in_waiting:
    line = ser.readline().decode('utf-8', errors='ignore').strip()
    print(f"   Startup: {line}")

print("\n" + "="*60)
print("📤 SENDING TEST COMMANDS")
print("="*60 + "\n")

# =========================
# TEST 1: Send STUDENT command
# =========================
print("Test 1: Sending STUDENT:TEST123")
print("-" * 60)
ser.write(b"STUDENT:TEST123\n")

print("⏳ Waiting for response...")
start = time.time()
received_lines = []

while time.time() - start < 3:
    if ser.in_waiting:
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        if line:
            print(f"  📥 {line}")
            received_lines.append(line)

if received_lines:
    print("\n✅ Received response from Arduino!")
    print("\n🖥️  Check your LCD display:")
    print("  Line 1 should show: Hello Student!")
    print("  Line 2 should show: TEST123")
else:
    print("\n❌ No response received!")
    print("\nPossible issues:")
    print("  1. bottle_sensor.ino not uploaded")
    print("  2. Wrong COM port")
    print("  3. Baud rate mismatch")

input("\nPress Enter to continue to Test 2...")

# =========================
# TEST 2: Send with real student ID
# =========================
print("\n" + "="*60)
print("Test 2: Sending STUDENT:2021-12345")
print("-" * 60)
ser.write(b"STUDENT:2021-12345\n")

print("⏳ Waiting for response...")
start = time.time()
received_lines = []

while time.time() - start < 3:
    if ser.in_waiting:
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        if line:
            print(f"  📥 {line}")
            received_lines.append(line)

if received_lines:
    print("\n✅ Received response!")
    print("\n🖥️  Check your LCD display:")
    print("  Line 1 should show: Hello Student!")
    print("  Line 2 should show: 2021-12345")
else:
    print("\n❌ No response received!")

input("\nPress Enter to continue to Test 3...")

# =========================
# TEST 3: Send SESSION_END
# =========================
print("\n" + "="*60)
print("Test 3: Sending SESSION_END")
print("-" * 60)
ser.write(b"SESSION_END\n")

print("⏳ Waiting for response...")
start = time.time()

while time.time() - start < 3:
    if ser.in_waiting:
        line = ser.readline().decode('utf-8', errors='ignore').strip()
        if line:
            print(f"  📥 {line}")

print("\n🖥️  Check your LCD display:")
print("  Should return to: Scan QR code / to start...")

# =========================
# CLEANUP
# =========================
print("\n" + "="*60)
print("🏁 TEST COMPLETE")
print("="*60 + "\n")

ser.close()
print("✅ Serial port closed")

print("\n📊 Summary:")
print("-" * 60)
print("If LCD changed during tests → ✅ Bottle Sensor works!")
print("If LCD didn't change → ❌ Check:")
print("  1. LCD connections (SDA to A4, SCL to A5)")
print("  2. LCD address (0x27 or 0x3F in code)")
print("  3. LCD I2C module powered")
print("\nIf tests show responses but LCD doesn't change:")
print("  → LCD hardware issue, not communication issue")
print("\nIf no responses received:")
print("  → Serial communication issue")
print("  → Check bottle_sensor.ino is uploaded")
print("  → Check correct COM port")
print("\n" + "="*60)

input("\nPress Enter to exit...")
