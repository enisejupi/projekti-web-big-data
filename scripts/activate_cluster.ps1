# ========================================
# ULTIMATE CLUSTER ACTIVATION
# Utilizes all 10 VMs for maximum performance
# ========================================

param([switch]$Quick)

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  ACTIVATING FULL CLUSTER POWER" -ForegroundColor Cyan
Write-Host "  Using all 10 VMs for data collection" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Upload and run the activation script
$activationScript = "c:\Users\Lenovo\projekti-web-info\scripts\activate_full_cluster.sh"

if (Test-Path $activationScript) {
    Write-Host "[*] Uploading activation script..." -ForegroundColor Yellow
    scp -P $VM_PORT $activationScript "$VM_USER@${VM_HOST}:/tmp/activate_cluster.sh"
    
    Write-Host "`n[*] Executing full cluster activation...`n" -ForegroundColor Yellow
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "bash /tmp/activate_cluster.sh"
} else {
    Write-Host "[ERROR] Activation script not found!" -ForegroundColor Red
    Write-Host "Expected: $activationScript`n" -ForegroundColor Gray
    exit 1
}

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  CLUSTER ACTIVATION COMPLETE!" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Green

Write-Host "What's happening now:" -ForegroundColor Yellow
Write-Host "  → All 10 VMs are processing data in parallel" -ForegroundColor White
Write-Host "  → Advanced Spark collector is running" -ForegroundColor White
Write-Host "  → Expected: 100-500 records/second" -ForegroundColor White
Write-Host "  → ML predictions scheduled every 30 minutes`n" -ForegroundColor White

Write-Host "Monitor progress:" -ForegroundColor Cyan
Write-Host "  1. Check data growth:" -ForegroundColor White
Write-Host "     .\manage.ps1 -Action check-data`n" -ForegroundColor Gray
Write-Host "  2. View Spark UI (after port forwarding):" -ForegroundColor White
Write-Host "     http://localhost:8080`n" -ForegroundColor Gray
Write-Host "  3. View Dashboard:" -ForegroundColor White
Write-Host "     http://localhost:8050`n" -ForegroundColor Gray

Write-Host "Tip: Wait 5-10 minutes, then check the dashboard!" -ForegroundColor Yellow
Write-Host "     You should see records increasing rapidly.`n" -ForegroundColor Yellow
