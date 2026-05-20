"""
Test COM port access for T2T Arduino system
"""
import serial
import serial.tools.list_ports

QR_SCANNER_PORT = "COM10"
BOTTLE_SENSOR_PORT = "COM4"
BAUD = 9600

print("\n" + "="*50)
print("🔌 T2T COM PORT DIAGNOSTIC")
print("="*50 + "\n")

# List all available ports
print("📋 Available COM Ports:")
ports = serial.tools.list_ports.comports()
for p in ports:
    print(f"   • {p.device} - {p.description}")
print()

# Test COM10 (QR Scanner)
print(f"🔍 Testing {QR_SCANNER_PORT} (QR Scanner)...")
try:
    ser = serial.Serial(QR_SCANNER_PORT, BAUD, timeout=1)
    print(f"   ✅ SUCCESS - {QR_SCANNER_PORT} is accessible")
    ser.close()
except serial.SerialException as e:
    print(f"   ❌ FAILED - {e}")
    print(f"   → Close Arduino IDE Serial Monitor on {QR_SCANNER_PORT}")
    print(f"   → Or unplug/replug the device")
print()

# Test COM4 (Bottle Sensor)
print(f"🔍 Testing {BOTTLE_SENSOR_PORT} (Bottle Sensor)...")
try:
    ser = serial.Serial(BOTTLE_SENSOR_PORT, BAUD, timeout=1)
    print(f"   ✅ SUCCESS - {BOTTLE_SENSOR_PORT} is accessible")
    ser.close()
except serial.SerialException as e:
    print(f"   ❌ FAILED - {e}")
    print(f"   → Close Arduino IDE Serial Monitor on {BOTTLE_SENSOR_PORT}")
    print(f"   → Or unplug/replug the device")
print()

print("="*50)
print("💡 TROUBLESHOOTING TIPS:")
print("="*50)
print("1. Close Arduino IDE Serial Monitor")
print("2. Close Arduino IDE Serial Plotter")
print("3. Stop any running bridge.py instances")
print("4. Unplug and replug Arduino devices")
print("5. Run this script again")
print()
