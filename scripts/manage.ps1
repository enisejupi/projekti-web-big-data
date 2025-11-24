# Management Script
param([string]$Action = "status")
$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host "`n==========================================`n" -ForegroundColor Cyan
Write-Host " Financial Analysis Management`n" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan

if ($Action -eq "start-free-collector") {
    Write-Host "[*] Starting FREE API Collector...`n" -ForegroundColor Yellow
    Write-Host "This will prompt for SSH password 3 times.`n" -ForegroundColor Gray
    
    Write-Host "[1/3] Uploading collector script..." -ForegroundColor Cyan
    scp -P $VM_PORT "$PSScriptRoot\..\spark_apps\free_api_collector.py" "${VM_USER}@${VM_HOST}:/opt/financial-analysis/spark_apps/"
    
    Write-Host "`n[2/3] Stopping old collectors..." -ForegroundColor Cyan
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "pkill -f data_collector.py; pkill -f advanced_collector.py; pkill -f multi_source_collector.py; sleep 2"
    
    Write-Host "`n[3/3] Starting new collector..." -ForegroundColor Cyan
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "cd /opt/financial-analysis/spark_apps && nohup python3.9 free_api_collector.py > /opt/financial-analysis/logs/free_api_collector.out 2>&1 & echo \$! > /opt/financial-analysis/logs/free_api_collector.pid && sleep 3 && ps aux | grep free_api_collector.py | grep -v grep"
    
    Write-Host "`n==========================================`n" -ForegroundColor Green
    Write-Host "[✓] Collector started successfully!`n" -ForegroundColor Green
    Write-Host "Monitor logs:" -ForegroundColor Cyan
    Write-Host "  ssh -p $VM_PORT ${VM_USER}@${VM_HOST} 'tail -f /opt/financial-analysis/logs/free_api_collector.log'`n" -ForegroundColor Gray
    Write-Host "Check data:" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 -Action check-data`n" -ForegroundColor Gray
    Write-Host "==========================================`n" -ForegroundColor Green
}
elseif ($Action -eq "port-forward") {
    Write-Host "[*] Setting up SSH Port Forwarding...`n" -ForegroundColor Yellow
    Write-Host "==========================================`n" -ForegroundColor Cyan
    Write-Host "Forwarding ports to localhost:`n" -ForegroundColor Cyan
    Write-Host "  - Dashboard:       http://localhost:8050" -ForegroundColor Green
    Write-Host "  - Spark Master UI: http://localhost:8080" -ForegroundColor Green
    Write-Host "  - Spark App UI:    http://localhost:4040" -ForegroundColor Green
    Write-Host "  - PostgreSQL:      localhost:5432`n" -ForegroundColor Green
    Write-Host "==========================================`n" -ForegroundColor Cyan
    Write-Host "Keep this terminal open!" -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop port forwarding`n" -ForegroundColor Red
    Write-Host "You will be prompted for SSH password once.`n" -ForegroundColor Gray
    
    ssh -N -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -L 4040:10.0.0.4:4040 -L 5432:10.0.0.4:5432 -p $VM_PORT "${VM_USER}@${VM_HOST}"
}
elseif ($Action -eq "status") {
    Write-Host "[*] Checking system status...`n" -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "bash /opt/financial-analysis/scripts/check_spark_status.sh"
}
elseif ($Action -eq "check-data") {
    Write-Host "[*] Checking data collection...`n" -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "echo '=== PostgreSQL Data ===' && psql -h 10.0.0.4 -U financeuser -d financial_data -c 'SELECT COUNT(*) as total_records FROM market_data;' 2>/dev/null || echo 'Database connection failed' && echo '' && echo '=== Parquet Files ===' && ls -lh /opt/financial-analysis/data/raw/*.parquet 2>/dev/null | tail -5 && echo '' && echo '=== Collector Process ===' && ps aux | grep free_api_collector.py | grep -v grep"
}
elseif ($Action -eq "fix-ml") {
    Write-Host "[*] Running ML & Presentation Fix...`n" -ForegroundColor Yellow
    & "$PSScriptRoot\fix_ml_and_presentation.ps1" -Action all
}
elseif ($Action -eq "generate-presentation") {
    Write-Host "[*] Generating presentation...`n" -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "cd /opt/financial-analysis/scripts && python3.9 generate_presentation.py && ls -lh /opt/financial-analysis/reports/*.pptx 2>/dev/null | tail -3"
}
elseif ($Action -eq "run-predictions") {
    Write-Host "[*] Running ML predictions...`n" -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "cd /opt/financial-analysis/spark_apps && python3.9 periodic_predictions.py"
}
else {
    Write-Host "Unknown action: $Action`n" -ForegroundColor Red
    Write-Host "Available actions:" -ForegroundColor Cyan
    Write-Host "  .\manage.ps1 -Action start-free-collector" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action port-forward" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action status" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action check-data" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action fix-ml              # Fix ML & Presentation issues" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action generate-presentation" -ForegroundColor Gray
    Write-Host "  .\manage.ps1 -Action run-predictions`n" -ForegroundColor Gray
}
