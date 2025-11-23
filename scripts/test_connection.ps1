# PowerShell Script për të Testuar Lidhjen me VM-të
# Ekzekutoni këtë para se të filloni deployment për të siguruar që të gjitha VM-të janë të arritshme

$ErrorActionPreference = "Continue"

$vms = @(
    @{Name="VM1"; IP="10.0.0.4"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"; Role="Master"},
    @{Name="VM2"; IP="10.0.0.5"; SSHPort=8023; User="krenuser"; Pass="ed6673p1GCasuoGn7OHS"; Role="Worker"},
    @{Name="VM3"; IP="10.0.0.6"; SSHPort=8024; User="krenuser"; Pass="93becjVKKOzJEqserofC"; Role="Worker"},
    @{Name="VM4"; IP="10.0.0.7"; SSHPort=8025; User="krenuser"; Pass="55t6o9wPd3U7Pqt4sJVV"; Role="Worker"},
    @{Name="VM5"; IP="10.0.0.8"; SSHPort=8026; User="krenuser"; Pass="M3t01MISTXef3J6Uspck"; Role="Worker"},
    @{Name="VM6"; IP="10.0.0.9"; SSHPort=8027; User="krenuser"; Pass="lEwxgSAZa7T8lY85Z7UM"; Role="Worker"},
    @{Name="VM7"; IP="10.0.0.10"; SSHPort=8028; User="krenuser"; Pass="3rcQePQnsV5bBZ9YULSd"; Role="Worker"},
    @{Name="VM8"; IP="10.0.0.11"; SSHPort=8029; User="krenuser"; Pass="iCeKbi51jKmtL3XmEVhG"; Role="Worker"},
    @{Name="VM9"; IP="10.0.0.12"; SSHPort=8030; User="krenuser"; Pass="hww1F8lLz21cFKHYBwYL"; Role="Worker"},
    @{Name="VM10"; IP="10.0.0.13"; SSHPort=8031; User="krenuser"; Pass="j67k4k6QAl1l9TDmEgsN"; Role="Worker"}
)

$baseHost = "185.182.158.150"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Testimi i Lidhjes me VM-te" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Accept host keys for all VMs first (one-time operation)
Write-Host "Duke pranuar host keys..." -ForegroundColor Yellow
foreach ($vm in $vms) {
    $acceptCmd = "echo y | plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) krenuser@${baseHost} exit"
    Invoke-Expression $acceptCmd 2>&1 | Out-Null
}
Write-Host "[OK] Host keys u pranuan" -ForegroundColor Green
Write-Host ""

$successCount = 0
$failCount = 0

foreach ($vm in $vms) {
    Write-Host "Duke testuar $($vm.Name) ($($vm.Role))..." -ForegroundColor Yellow -NoNewline
    
    $testCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch krenuser@${baseHost} `"echo SUCCESS`""
    
    try {
        $result = Invoke-Expression $testCmd 2>&1
        
        if ($result -match "SUCCESS") {
            Write-Host " [OK]" -ForegroundColor Green
            $successCount++
            
            # Testo RAM dhe CPU
            $ramCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch krenuser@${baseHost} `"free -h | grep Mem`""
            $ramInfo = Invoke-Expression $ramCmd 2>&1
            Write-Host "  RAM: $ramInfo" -ForegroundColor Gray
            
            $cpuCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch krenuser@${baseHost} `"nproc`""
            $cpuCount = Invoke-Expression $cpuCmd 2>&1
            Write-Host "  CPU cores: $cpuCount" -ForegroundColor Gray
        } else {
            Write-Host " [FAIL]" -ForegroundColor Red
            $failCount++
        }
    } catch {
        Write-Host " [FAIL]" -ForegroundColor Red
        $failCount++
    }
    
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Rezultatet e Testimit" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Sukses: $successCount / $($vms.Count)" -ForegroundColor Green
Write-Host "Dështime: $failCount / $($vms.Count)" -ForegroundColor Red
Write-Host ""

if ($successCount -eq $vms.Count) {
    Write-Host "[OK] Te gjitha VM-te jane te arritshme!" -ForegroundColor Green
    Write-Host "Mund te vazhdoni me deployment: .\scripts\deploy_all.ps1" -ForegroundColor Cyan
} else {
    Write-Host "[WARNING] Disa VM nuk jane te arritshme!" -ForegroundColor Yellow
    Write-Host "Kontrolloni lidhjen ne internet dhe kredencialet." -ForegroundColor Yellow
}

Write-Host ""
