# ============================================
# T2T COM Port Troubleshooter
# ============================================
# This script helps identify what's blocking COM10

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "🔧 T2T COM PORT TROUBLESHOOTER" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Check for Arduino IDE processes
Write-Host "🔍 Checking for Arduino IDE processes..." -ForegroundColor Yellow
$arduinoProcesses = Get-Process | Where-Object {$_.ProcessName -match "arduino"}
if ($arduinoProcesses) {
    Write-Host "❌ Found Arduino IDE running:" -ForegroundColor Red
    $arduinoProcesses | ForEach-Object {
        Write-Host "   • $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Red
    }
    Write-Host "`n💡 Solution: Close Arduino IDE completely`n" -ForegroundColor Green
} else {
    Write-Host "✅ No Arduino IDE processes found`n" -ForegroundColor Green
}

# Check for Python processes that might be using serial ports
Write-Host "🔍 Checking for Python processes..." -ForegroundColor Yellow
$pythonProcesses = Get-Process | Where-Object {$_.ProcessName -match "python"}
if ($pythonProcesses) {
    Write-Host "⚠️  Found Python processes:" -ForegroundColor Yellow
    $pythonProcesses | ForEach-Object {
        Write-Host "   • $($_.ProcessName) (PID: $($_.Id))" -ForegroundColor Yellow
    }
    Write-Host "`n💡 If bridge.py is already running, press Ctrl+C to stop it`n" -ForegroundColor Green
} else {
    Write-Host "✅ No Python processes found`n" -ForegroundColor Green
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "📋 QUICK FIX STEPS:" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "1. Close Arduino IDE Serial Monitor"
Write-Host "2. Close Arduino IDE completely"
Write-Host "3. Press Ctrl+C in any terminals running bridge.py"
Write-Host "4. Unplug QR Scanner Arduino from USB"
Write-Host "5. Wait 3 seconds"
Write-Host "6. Plug it back in"
Write-Host "7. Run: python arduino\bridge.py"
Write-Host "============================================`n" -ForegroundColor Cyan
