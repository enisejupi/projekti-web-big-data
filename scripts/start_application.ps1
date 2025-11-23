# PowerShell Script to Start the Complete Application

$ErrorActionPreference = "Continue"

$master = @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"}
$baseHost = "185.182.158.150"

Write-Host "============================================" -ForegroundColor Green
Write-Host "Starting Full Application" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command, $background = $false)
    
    if ($background) {
        $fullCommand = "nohup $command > /opt/financial-analysis/logs/app.log 2>&1 &"
    } else {
        $fullCommand = $command
    }
    
    $plinkCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch $($vm.User)@${baseHost} `"$fullCommand`""
    Invoke-Expression $plinkCmd
}

Write-Host "Saving start time..." -ForegroundColor Cyan
$startTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
Invoke-SSHCommand -vm $master -command "echo '$startTime' > /opt/financial-analysis/logs/start_time.txt"

Write-Host ""
Write-Host "Phase 1: Starting Data Collector..." -ForegroundColor Yellow
Write-Host "This will collect data for 3.5 days (84 hours)" -ForegroundColor Yellow
Write-Host ""

$collectorCmd = "export PYSPARK_PYTHON=/usr/bin/python3.9 ; cd /opt/financial-analysis ; /opt/spark/bin/spark-submit --master spark://10.0.0.4:7077 --executor-memory 130g --driver-memory 120g --executor-cores 16 --total-executor-cores 144 spark_apps/data_collector.py"
Invoke-SSHCommand -vm $master -command $collectorCmd -background $true

Write-Host "  Data Collector started in background" -ForegroundColor Green
Start-Sleep -Seconds 5

Write-Host ""
Write-Host "Waiting 30 minutes for initial data collection..." -ForegroundColor Yellow
Write-Host "(This time is needed to have enough data for training)" -ForegroundColor Yellow
Write-Host ""

for ($i = 30; $i -gt 0; $i--) {
    Write-Host "  $i minutes remaining..." -ForegroundColor Cyan
    Start-Sleep -Seconds 60
}

Write-Host ""
Write-Host "Phase 2: Training ML models..." -ForegroundColor Yellow
Write-Host ""

$mlCmd = "export PYSPARK_PYTHON=/usr/bin/python3.9 ; cd /opt/financial-analysis ; /opt/spark/bin/spark-submit --master spark://10.0.0.4:7077 --executor-memory 130g --driver-memory 120g --executor-cores 16 --total-executor-cores 144 ml_models/predictor.py"
Invoke-SSHCommand -vm $master -command $mlCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "  Models trained successfully" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Training had issues, but continuing..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Phase 3: Starting Dashboard..." -ForegroundColor Yellow
Write-Host ""

$dashboardCmd = "cd /opt/financial-analysis/dashboard ; python3.9 app.py"
Invoke-SSHCommand -vm $master -command $dashboardCmd -background $true

Write-Host "  Dashboard started in background" -ForegroundColor Green
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "Phase 4: Configuring Port Forwarding..." -ForegroundColor Yellow
Write-Host ""

Write-Host "To access Dashboard and Spark UI locally, run this command:" -ForegroundColor Cyan
Write-Host ""
Write-Host "ssh -L 8050:10.0.0.4:8050 -L 9090:10.0.0.4:9090 -p 8022 krenuser@185.182.158.150" -ForegroundColor White
Write-Host ""
Write-Host "Then open browser:" -ForegroundColor Cyan
Write-Host "  Dashboard: http://localhost:8050" -ForegroundColor White
Write-Host "  Spark UI:  http://localhost:9090" -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Application Started Successfully!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Execution Details:" -ForegroundColor Cyan
Write-Host "  Duration: 84 hours - 3.5 days" -ForegroundColor White
Write-Host "  Data Collection: Every 5 minutes" -ForegroundColor White
Write-Host "  ML Models: Random Forest, GBT, LSTM, K-Means" -ForegroundColor White
Write-Host "  Dashboard: Updates every 30 seconds" -ForegroundColor White
Write-Host "  Target Accuracy: 90plus" -ForegroundColor White
Write-Host ""
Write-Host "To monitor:" -ForegroundColor Yellow
Write-Host "  Logs: tail -f /opt/financial-analysis/logs/*.log" -ForegroundColor White
Write-Host "  Cluster status: scripts/check_cluster.ps1" -ForegroundColor White
Write-Host ""
Write-Host "To stop:" -ForegroundColor Yellow
Write-Host "  Run: scripts/stop_application.ps1" -ForegroundColor White
Write-Host ""
