# PowerShell Script to Check Spark Cluster Status
# Kontrollon statusin e Spark Cluster dhe aplikacionit

$ErrorActionPreference = "Continue"

$master = @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"}
$baseHost = "185.182.158.150"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Spark Cluster Status Check" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command)
    
    $plinkCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch $($vm.User)@${baseHost} `"$command`""
    Invoke-Expression $plinkCmd
}

# Check Spark Master
Write-Host "Spark Master Status:" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "jps | grep Master"
Write-Host ""

# Check Spark Workers
Write-Host "Spark Workers Status:" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "jps | grep Worker"
Write-Host ""

# Check Dashboard
Write-Host "Dashboard Status:" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "ps aux | grep 'dashboard/app.py' | grep -v grep | wc -l"
Write-Host ""

# Check Data Collector
Write-Host "Data Collector Status:" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "ps aux | grep 'data_collector.py' | grep -v grep | wc -l"
Write-Host ""

# Check logs
Write-Host "Recent Logs (last 10 lines):" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "tail -10 /opt/financial-analysis/logs/*.log 2>/dev/null || echo 'No logs found yet'"
Write-Host ""

# Check data files
Write-Host "Data Files:" -ForegroundColor Yellow
Invoke-SSHCommand -vm $master -command "ls -lh /opt/financial-analysis/data/ 2>/dev/null || echo 'No data directory yet'"
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "To view live logs:" -ForegroundColor Cyan
Write-Host "  ssh -p 8022 krenuser@185.182.158.150" -ForegroundColor White
Write-Host "  tail -f /opt/financial-analysis/logs/*.log" -ForegroundColor White
Write-Host ""
Write-Host "To access Spark UI:" -ForegroundColor Cyan
Write-Host "  http://localhost:9090 (after port forwarding)" -ForegroundColor White
Write-Host ""
Write-Host "To access Dashboard:" -ForegroundColor Cyan
Write-Host "  http://localhost:8050 (after port forwarding)" -ForegroundColor White
Write-Host ""
