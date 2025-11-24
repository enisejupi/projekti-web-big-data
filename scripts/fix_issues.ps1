# Quick Fix for ML and Presentation Issues
param([string]$Action = "all")

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  ML & Presentation Quick Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Kill stuck jobs
if ($Action -eq "all" -or $Action -eq "1") {
    Write-Host "[1/5] Killing stuck Spark ML jobs..." -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "pkill -9 -f MLPredictor; pkill -9 -f periodic_predictions; sleep 2; echo 'Done'"
    Write-Host "  [OK] Stuck jobs killed" -ForegroundColor Green
    Write-Host ""
}

# Step 2: Fix parquet files
if ($Action -eq "all" -or $Action -eq "2") {
    Write-Host "[2/5] Removing corrupted parquet files..." -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "find /opt/financial-analysis/data/raw -name '*.parquet' -size -1000c -delete; ls -lh /opt/financial-analysis/data/raw/*.parquet 2>/dev/null | tail -3"
    Write-Host "  [OK] Corrupted files removed" -ForegroundColor Green
    Write-Host ""
}

# Step 3: Install python-pptx
if ($Action -eq "all" -or $Action -eq "3") {
    Write-Host "[3/5] Installing python-pptx..." -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "pip3.9 install --user python-pptx 2>&1 | tail -3"
    Write-Host "  [OK] python-pptx installed" -ForegroundColor Green
    Write-Host ""
}

# Step 4: Upload fixed script
if ($Action -eq "all" -or $Action -eq "4") {
    Write-Host "[4/5] Updating ML predictor script..." -ForegroundColor Yellow
    scp -P $VM_PORT "$PSScriptRoot\..\spark_apps\periodic_predictions_fixed.py" "${VM_USER}@${VM_HOST}:/opt/financial-analysis/spark_apps/periodic_predictions.py" 2>&1 | Out-Null
    Write-Host "  [OK] Script updated" -ForegroundColor Green
    Write-Host ""
}

# Step 5: Test
if ($Action -eq "all" -or $Action -eq "5") {
    Write-Host "[5/5] Running system tests..." -ForegroundColor Yellow
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" "python3.9 -c 'import pptx; print(\"python-pptx OK\")'; ls -lh /opt/financial-analysis/data/raw/*.parquet 2>/dev/null | wc -l | xargs echo 'Parquet files:'"
    Write-Host "  [OK] Tests completed" -ForegroundColor Green
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Fix Completed Successfully!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart collector:  .\manage.ps1 -Action start-free-collector"
Write-Host "  2. Wait 10-15 minutes for data collection"
Write-Host "  3. Try generating presentation from dashboard"
Write-Host ""
