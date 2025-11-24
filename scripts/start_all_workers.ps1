# Fix permissions and start all Spark workers

param(
    [Parameter(Mandatory=$false)]
    [switch]$FixPermissions = $false
)

$VM_HOST = "185.182.158.150"
$VM_USER = "krenuser"
$workerPorts = @(8023, 8024, 8025, 8026, 8027, 8028, 8029, 8030, 8031)

Write-Host "`n========================================`n" -ForegroundColor Cyan
Write-Host " Starting Spark Workers`n" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$workerNum = 2
foreach ($port in $workerPorts) {
    Write-Host "  [VM$workerNum - Port $port]" -ForegroundColor Yellow
    
    if ($FixPermissions) {
        Write-Host "    Fixing /tmp/spark permissions..." -ForegroundColor Gray
        $fixCmd = "sudo mkdir -p /tmp/spark; sudo chmod 777 /tmp/spark"
        ssh -o "StrictHostKeyChecking=no" -p $port "${VM_USER}@${VM_HOST}" $fixCmd 2>&1 | Out-Null
    }
    
    Write-Host "    Starting worker..." -ForegroundColor Gray
    $startCmd = "/opt/spark/sbin/start-worker.sh spark://10.0.0.4:7077"
    $result = ssh -o "StrictHostKeyChecking=no" -p $port "${VM_USER}@${VM_HOST}" $startCmd 2>&1
    
    if ($result -match "starting.*Worker") {
        Write-Host "    [OK] Worker started successfully`n" -ForegroundColor Green
    } else {
        Write-Host "    [WARNING] $result`n" -ForegroundColor Yellow
    }
    
    $workerNum++
}

Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "Waiting 10 seconds for workers to register...`n" -ForegroundColor Gray
Start-Sleep -Seconds 10

Write-Host "[*] Checking worker status...`n" -ForegroundColor Yellow
ssh -p 8022 "${VM_USER}@${VM_HOST}" "ps aux | grep 'org.apache.spark.deploy.worker.Worker' | grep -v grep | wc -l"

Write-Host "`n========================================`n" -ForegroundColor Cyan
Write-Host " Usage:`n" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
Write-Host "  .\start_all_workers.ps1                # Start workers`n" -ForegroundColor Gray
Write-Host "  .\start_all_workers.ps1 -FixPermissions # Fix permissions first`n" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan
