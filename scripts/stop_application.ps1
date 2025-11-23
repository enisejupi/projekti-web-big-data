# PowerShell Script to Stop All Applications

$ErrorActionPreference = "Continue"

$master = @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"}
$workers = @(
    @{Name="VM2"; IP="10.0.0.5"; SSHPort=8023; User="krenuser"; Pass="ed6673p1GCasuoGn7OHS"},
    @{Name="VM3"; IP="10.0.0.6"; SSHPort=8024; User="krenuser"; Pass="93becjVKKOzJEqserofC"},
    @{Name="VM4"; IP="10.0.0.7"; SSHPort=8025; User="krenuser"; Pass="55t6o9wPd3U7Pqt4sJVV"},
    @{Name="VM5"; IP="10.0.0.8"; SSHPort=8026; User="krenuser"; Pass="M3t01MISTXef3J6Uspck"},
    @{Name="VM6"; IP="10.0.0.9"; SSHPort=8027; User="krenuser"; Pass="lEwxgSAZa7T8lY85Z7UM"},
    @{Name="VM7"; IP="10.0.0.10"; SSHPort=8028; User="krenuser"; Pass="3rcQePQnsV5bBZ9YULSd"},
    @{Name="VM8"; IP="10.0.0.11"; SSHPort=8029; User="krenuser"; Pass="iCeKbi51jKmtL3XmEVhG"},
    @{Name="VM9"; IP="10.0.0.12"; SSHPort=8030; User="krenuser"; Pass="hww1F8lLz21cFKHYBwYL"},
    @{Name="VM10"; IP="10.0.0.13"; SSHPort=8031; User="krenuser"; Pass="j67k4k6QAl1l9TDmEgsN"}
)

$baseHost = "185.182.158.150"

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Ndalja e të Gjitha Aplikacioneve" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command)
    
    $sshTarget = "${baseHost}:$($vm.SSHPort)"
    $plinkCmd = "echo y | plink -ssh -pw $($vm.Pass) $($vm.User)@${sshTarget} `"$command`""
    Invoke-Expression $plinkCmd
}

# Stop applications on master
Write-Host "Duke ndalur aplikacionet në Master..." -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "pkill -f data_collector.py; pkill -f predictor.py; pkill -f 'dashboard/app.py'"
Write-Host "  ✓ Aplikacionet u ndalen" -ForegroundColor Green

# Stop Spark workers
Write-Host ""
Write-Host "Duke ndalur Spark Workers..." -ForegroundColor Cyan
foreach ($worker in $workers) {
    Invoke-SSHCommand -vm $worker -command "/opt/spark/sbin/stop-worker.sh"
    Write-Host "  ✓ Worker në $($worker.Name) u ndal" -ForegroundColor Green
}

# Stop Spark master
Write-Host ""
Write-Host "Duke ndalur Spark Master..." -ForegroundColor Cyan
Invoke-SSHCommand -vm $master -command "/opt/spark/sbin/stop-master.sh"
Write-Host "  ✓ Master u ndal" -ForegroundColor Green

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Të gjitha shërbimet u ndalen!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
