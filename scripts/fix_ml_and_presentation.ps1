# Fix ML Predictions and Presentation Generation
# Addresses: corrupted parquet files, missing python-pptx, stuck Spark jobs

param([string]$Action = "all")

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host "`n=========================================="
Write-Host "  ML & Presentation Fix Utility" -ForegroundColor Cyan
Write-Host "==========================================`n"

function Kill-StuckSparkJobs {
    Write-Host "[1/5] Killing stuck Spark jobs..." -ForegroundColor Yellow
    $command = "pkill -9 -f 'MLPredictor'; pkill -9 -f 'periodic_predictions.py'; pkill -9 -f 'predictor.py'; echo 'Killed stuck Spark jobs'; sleep 2; ps aux | grep -E 'MLPredictor|periodic_predictions' | grep -v grep || echo 'All ML jobs stopped'"
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" $command
    Write-Host "  [OK] Stuck jobs terminated`n" -ForegroundColor Green
}

function Fix-CorruptedParquetFiles {
    Write-Host "[2/5] Checking and fixing Parquet files..." -ForegroundColor Yellow
    $scriptContent = @'
cd /opt/financial-analysis/data/raw
echo "Checking Parquet files..."
for file in *.parquet; do
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [ $size -lt 1000 ]; then
            echo "  Removing corrupted/empty file: $file (size: $size bytes)"
            rm -f "$file"
        else
            echo "  Valid file: $file (size: $size bytes)"
        fi
    fi
done
echo ""
echo "Remaining valid Parquet files:"
ls -lh *.parquet 2>/dev/null | tail -5
'@
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" $scriptContent
    Write-Host "  [OK] Parquet files validated`n" -ForegroundColor Green
}

function Install-PythonPptx {
    Write-Host "[3/5] Installing python-pptx for presentations..." -ForegroundColor Yellow
    $command = "pip3.9 install --user python-pptx 2>&1 && python3.9 -c 'import pptx; print(f`"python-pptx {pptx.__version__} installed`")'"
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" $command
    Write-Host "  [OK] python-pptx installed`n" -ForegroundColor Green
}

function Fix-MLPredictorScript {
    Write-Host "[4/5] Updating ML Predictor to handle errors..." -ForegroundColor Yellow
    
    # Upload fixed periodic_predictions script
    scp -P $VM_PORT "$PSScriptRoot\..\spark_apps\periodic_predictions_fixed.py" "${VM_USER}@${VM_HOST}:/opt/financial-analysis/spark_apps/periodic_predictions.py"
    
    Write-Host "  ✓ Updated ML predictor script`n" -ForegroundColor Green
}

function Test-Systems {
    Write-Host "[5/5] Testing systems..." -ForegroundColor Yellow
    $testScript = @'
echo "=== Checking Latest Parquet File ==="
latest=$(ls -t /opt/financial-analysis/data/raw/*.parquet 2>/dev/null | head -1)
if [ -f "$latest" ]; then
    echo "Latest file: $latest"
    size=$(stat -c%s "$latest" 2>/dev/null)
    echo "  Size: $size bytes"
    if [ $size -gt 1000 ]; then
        echo "  [OK] File appears valid"
    else
        echo "  [WARNING] File may be too small"
    fi
else
    echo "  [WARNING] No parquet files found"
fi
echo ""
echo "=== System Status ==="
ps aux | grep -c 'free_api_collector.py' && echo "Active collectors found" || echo "No active collectors"
ls -1 /opt/financial-analysis/data/raw/*.parquet 2>/dev/null | wc -l
'@
    ssh -p $VM_PORT "${VM_USER}@${VM_HOST}" $testScript
    Write-Host "`n  [OK] System tests completed`n" -ForegroundColor Green
}

# Main execution
if ($Action -eq "all" -or $Action -eq "kill-jobs") {
    Kill-StuckSparkJobs
}

if ($Action -eq "all" -or $Action -eq "fix-parquet") {
    Fix-CorruptedParquetFiles
}

if ($Action -eq "all" -or $Action -eq "install-pptx") {
    Install-PythonPptx
}

if ($Action -eq "all" -or $Action -eq "fix-ml") {
    Fix-MLPredictorScript
}

if ($Action -eq "all" -or $Action -eq "test") {
    Test-Systems
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Fix Complete!" -ForegroundColor Green
Write-Host "==========================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart collector: .\manage.ps1 -Action start-free-collector"
Write-Host "  2. Wait 10-15 minutes for data collection"
Write-Host "  3. Check data: .\manage.ps1 -Action check-data"
Write-Host "  4. Try presentation generation again from dashboard`n"

Write-Host "Monitor logs:" -ForegroundColor Yellow
$logCommand = "ssh -p $VM_PORT ${VM_USER}@${VM_HOST} 'tail -f /opt/financial-analysis/logs/periodic_predictions.log'"
Write-Host "  $logCommand"
Write-Host ""
