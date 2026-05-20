"""
============================================
T2T COM Port Troubleshooter
============================================
Helps identify what's blocking COM10
"""
import subprocess
import sys

def run_command(cmd):
    """Run a PowerShell command and return output"""
    try:
        result = subprocess.run(
            ["powershell", "-Command", cmd],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip()
    except:
        return ""

print("\n" + "="*50)
print("TROUBLESHOOTER - COM Port Blocker")
print("="*50 + "\n")

# Check for Arduino IDE
print("Checking for Arduino IDE processes...")
arduino_check = run_command("Get-Process | Where-Object {$_.ProcessName -match 'arduino'} | Select-Object ProcessName, Id")
if arduino_check and "arduino" in arduino_check.lower():
    print("   FOUND: Arduino IDE is running!")
    print("   ACTION: Close Arduino IDE completely\n")
else:
    print("   OK: No Arduino IDE found\n")

# Check for Python processes
print("Checking for Python processes...")
python_check = run_command("Get-Process | Where-Object {$_.ProcessName -match 'python'} | Select-Object ProcessName, Id")
if python_check and "python" in python_check.lower():
    print("   WARNING: Python processes found")
    print("   ACTION: Stop any running bridge.py (Ctrl+C)\n")
else:
    print("   OK: No Python processes found\n")

print("="*50)
print("QUICK FIX - Follow these steps:")
print("="*50)
print("1. Close Arduino IDE Serial Monitor")
print("2. Close Arduino IDE completely")
print("3. In VS Code, press Ctrl+C in any terminal running bridge.py")
print("4. Unplug QR Scanner Arduino (COM10) from USB")
print("5. Wait 5 seconds")
print("6. Plug it back in")
print("7. Run: python bridge.py")
print("="*50 + "\n")
