# PowerShell Script to Start Spark Cluster
# Nis Master në VM1 dhe të gjithë Workers në VM2-VM10

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

Write-Host "============================================" -ForegroundColor Green
Write-Host "Nisja e Spark Cluster" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command, $background = $false)
    
    if ($background) {
        $fullCommand = "nohup $command > /dev/null 2>&1 &"
    } else {
        $fullCommand = $command
    }
    
    $plinkCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch $($vm.User)@${baseHost} `"$fullCommand`""
    Invoke-Expression $plinkCmd
}

# Start Master
Write-Host "Duke nisur Spark Master ne VM1..." -ForegroundColor Cyan

# Check if Master is already running
$masterCheck = Invoke-SSHCommand -vm $master -command "jps | grep -c Master"
if ($masterCheck -match "1") {
    Write-Host "  [INFO] Spark Master eshte duke ekzekutuar paraprakisht" -ForegroundColor Yellow
} else {
    Invoke-SSHCommand -vm $master -command "/opt/spark/sbin/start-master.sh"
    Start-Sleep -Seconds 10
    Write-Host "  [OK] Spark Master u nis me sukses" -ForegroundColor Green
}

Write-Host ""

# Start Workers
Write-Host "Duke nisur Spark Workers ne VM2-VM10..." -ForegroundColor Cyan

foreach ($worker in $workers) {
    Write-Host "  Duke nisur Worker ne $($worker.Name)..." -ForegroundColor Yellow
    
    # Check if worker is already running
    $workerCheck = Invoke-SSHCommand -vm $worker -command "jps | grep -c Worker"
    if ($workerCheck -match "1") {
        Write-Host "    [INFO] Worker ne $($worker.Name) eshte duke ekzekutuar paraprakisht" -ForegroundColor Yellow
    } else {
        Invoke-SSHCommand -vm $worker -command "/opt/spark/sbin/start-worker.sh spark://10.0.0.4:7077"
        Start-Sleep -Seconds 5
        Write-Host "    [OK] Worker ne $($worker.Name) u nis me sukses" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Spark Cluster u nis me sukses!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Informacion i Cluster:" -ForegroundColor Cyan
Write-Host "  Master URL: spark://10.0.0.4:7077" -ForegroundColor White
Write-Host "  Master Web UI: http://localhost:9090 (pas port forwarding)" -ForegroundColor White
Write-Host "  Workers: 9 nodes (VM2-VM10)" -ForegroundColor White
Write-Host ""
Write-Host "Per te vendosur port forwarding, ekzekutoni:" -ForegroundColor Yellow
Write-Host "  ssh -L 9090:10.0.0.4:9090 -L 8050:10.0.0.4:8050 -p 8022 krenuser@185.182.158.150" -ForegroundColor White
Write-Host ""
