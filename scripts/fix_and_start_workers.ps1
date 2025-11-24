# Fix permissions and start all workers

param(
    [switch]$OnlyMaster,
    [switch]$OnlyWorkers
)

$VM_HOST = "185.182.158.150"
$VM_USER = "krenuser"

$master = @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; Pass="jh87qLXHzFGt6gkb9ukV"}
$workers = @(
    @{Name="VM2"; IP="10.0.0.5"; SSHPort=8023; Pass="ed6673p1GCasuoGn7OHS"},
    @{Name="VM3"; IP="10.0.0.6"; SSHPort=8024; Pass="93becjVKKOzJEqserofC"},
    @{Name="VM4"; IP="10.0.0.7"; SSHPort=8025; Pass="55t6o9wPd3U7Pqt4sJVV"},
    @{Name="VM5"; IP="10.0.0.8"; SSHPort=8026; Pass="M3t01MISTXef3J6Uspck"},
    @{Name="VM6"; IP="10.0.0.9"; SSHPort=8027; Pass="lEwxgSAZa7T8lY85Z7UM"},
    @{Name="VM7"; IP="10.0.0.10"; SSHPort=8028; Pass="3rcQePQnsV5bBZ9YULSd"},
    @{Name="VM8"; IP="10.0.0.11"; SSHPort=8029; Pass="iCeKbi51jKmtL3XmEVhG"},
    @{Name="VM9"; IP="10.0.0.12"; SSHPort=8030; Pass="hww1F8lLz21cFKHYBwYL"},
    @{Name="VM10"; IP="10.0.0.13"; SSHPort=8031; Pass="j67k4k6QAl1l9TDmEgsN"}
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Fix Spark Permissions & Start Workers" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command)
    
    $sshCmd = "ssh -o StrictHostKeyChecking=no -p $($vm.SSHPort) $VM_USER@$VM_HOST `"$command`""
    
    Write-Host "  Executing on $($vm.Name)..." -ForegroundColor Gray
    
    # Use sshpass if available, otherwise try password in command
    $result = cmd /c "echo $($vm.Pass) | $sshCmd 2>&1"
    
    return $result
}

function Copy-ScriptToVM {
    param($vm, $localPath, $remotePath)
    
    $scpCmd = "scp -o StrictHostKeyChecking=no -P $($vm.SSHPort) $localPath ${VM_USER}@${VM_HOST}:${remotePath}"
    cmd /c "echo $($vm.Pass) | $scpCmd 2>&1" | Out-Null
}

# Fix master
if (-not $OnlyWorkers) {
    Write-Host "Fixing Master VM..." -ForegroundColor Yellow
    Write-Host ""
    
    # Copy fix script
    Copy-ScriptToVM -vm $master -localPath ".\fix_permissions_and_workers.sh" -remotePath "/tmp/fix_permissions.sh"
    
    # Execute fix - use semicolon instead of &&
    Invoke-SSHCommand -vm $master -command "chmod +x /tmp/fix_permissions.sh; bash /tmp/fix_permissions.sh"
    
    Write-Host "✓ Master fixed" -ForegroundColor Green
    Write-Host ""
}

# Start workers
if (-not $OnlyMaster) {
    Write-Host "Starting Workers on All VMs..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($worker in $workers) {
        Write-Host "Processing $($worker.Name) ($($worker.IP))..." -ForegroundColor Cyan
        
        # Copy worker script
        Copy-ScriptToVM -vm $worker -localPath ".\start_worker.sh" -remotePath "/tmp/start_worker.sh"
        
        # Execute - use semicolon instead of &&
        Invoke-SSHCommand -vm $worker -command "chmod +x /tmp/start_worker.sh; bash /tmp/start_worker.sh"
        
        Write-Host "✓ $($worker.Name) done" -ForegroundColor Green
        Write-Host ""
    }
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Check status:" -ForegroundColor Yellow
Write-Host "  .\deploy_master.ps1 -Action status" -ForegroundColor White
Write-Host ""
Write-Host "Or visit Spark Master UI:" -ForegroundColor Yellow
Write-Host "  http://localhost:8080 (with port forwarding)" -ForegroundColor White
