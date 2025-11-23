# PowerShell Script to Fix Python 3.10 Installation
# Run this to fix VMs that failed Python installation

$ErrorActionPreference = "Continue"

$vms = @(
    @{Name="VM1"; SSHPort=8022; User="krenuser"; Pass="jh87qLXHzFGt6gkb9ukV"},
    @{Name="VM3"; SSHPort=8024; User="krenuser"; Pass="93becjVKKOzJEqserofC"},
    @{Name="VM4"; SSHPort=8025; User="krenuser"; Pass="55t6o9wPd3U7Pqt4sJVV"},
    @{Name="VM5"; SSHPort=8026; User="krenuser"; Pass="M3t01MISTXef3J6Uspck"},
    @{Name="VM7"; SSHPort=8028; User="krenuser"; Pass="3rcQePQnsV5bBZ9YULSd"},
    @{Name="VM9"; SSHPort=8030; User="krenuser"; Pass="hww1F8lLz21cFKHYBwYL"},
    @{Name="VM10"; SSHPort=8031; User="krenuser"; Pass="j67k4k6QAl1l9TDmEgsN"}
)

$baseHost = "185.182.158.150"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Fixing Python 3.10 Installation" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-SSHCommand {
    param($vm, $command)
    
    $plinkCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch $($vm.User)@${baseHost} `"$command`""
    Invoke-Expression $plinkCmd
}

foreach ($vm in $vms) {
    Write-Host "Fixing $($vm.Name)..." -ForegroundColor Yellow
    
    # Add deadsnakes PPA and install Python 3.10
    $fixCmd = @"
sudo add-apt-repository -y ppa:deadsnakes/ppa; 
sudo apt-get update; 
sudo apt-get install -y python3.10 python3.10-venv python3.10-dev;
python3.10 --version
"@
    
    Invoke-SSHCommand -vm $vm -command $fixCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Python 3.10 installed successfully on $($vm.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Failed to install Python 3.10 on $($vm.Name)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Green
Write-Host "Python 3.10 Fix Completed!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now re-run the deployment:" -ForegroundColor Cyan
Write-Host "  .\scripts\master_deploy.ps1" -ForegroundColor Yellow
Write-Host ""
