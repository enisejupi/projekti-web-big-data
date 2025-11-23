# PowerShell Script to Check Cluster Status

$ErrorActionPreference = "Continue"

$master = @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"}
$baseHost = "185.182.158.150"

Write-Host "============================================" -ForegroundColor Green
Write-Host "Kontrolli i Statusit të Cluster" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command)
    
    $sshTarget = "${baseHost}:$($vm.SSHPort)"
    $plinkCmd = "echo y | plink -ssh -pw $($vm.Pass) $($vm.User)@${sshTarget} `"$command`""
    Invoke-Expression $plinkCmd
}

Write-Host "Spark Master Status:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "jps | grep Master"
Write-Host ""

Write-Host "Spark Worker Status (numri i proceseve):" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "for i in {5..13}; do ssh -o StrictHostKeyChecking=no 10.0.0.\$i 'jps | grep Worker'; done"
Write-Host ""

Write-Host "Aplikacionet Running:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "ps aux | grep -E '(data_collector|predictor|dashboard)' | grep -v grep"
Write-Host ""

Write-Host "Disk Usage:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "df -h /opt/financial-analysis"
Write-Host ""

Write-Host "Memory Usage:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "free -h"
Write-Host ""

Write-Host "Latest Data Files:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "ls -lh /opt/financial-analysis/data/raw/ | tail -5"
Write-Host ""

Write-Host "Runtime:" -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "if [ -f /opt/financial-analysis/logs/start_time.txt ]; then python3.10 -c 'from datetime import datetime; start=open(\"/opt/financial-analysis/logs/start_time.txt\").read().strip(); print(f\"Running for: {(datetime.now()-datetime.fromisoformat(start)).total_seconds()/3600:.1f} hours\")'; fi"
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
