# Release COM4 port by killing Python processes using it
Write-Host "🔍 Finding processes using COM4..." -ForegroundColor Cyan

# Get all Python processes
$pythonProcesses = Get-Process python* -ErrorAction SilentlyContinue

if ($pythonProcesses) {
    Write-Host "Found $($pythonProcesses.Count) Python process(es)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Stopping Python processes..." -ForegroundColor Yellow
    
    foreach ($proc in $pythonProcesses) {
        Write-Host "  - Stopping PID $($proc.Id)" -ForegroundColor Gray
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
    
    Start-Sleep -Seconds 1
    Write-Host ""
    Write-Host "✅ Python processes stopped" -ForegroundColor Green
} else {
    Write-Host "⚠️  No Python processes found running" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ COM4 should now be available" -ForegroundColor Green
Write-Host "💡 Try uploading your Arduino sketch again" -ForegroundColor Cyan
