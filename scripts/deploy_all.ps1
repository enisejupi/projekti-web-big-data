# PowerShell Script to Deploy Files and Install Spark on All VMs
# Ekzekutoni këtë skript nga Windows për të vendosur gjithçka në VM-të

param(
    [switch]$InstallOnly,
    [switch]$CopyOnly
)

$ErrorActionPreference = "Continue"

# VM Configuration
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
$projectPath = "c:\Users\Lenovo\projekti-web-info"

Write-Host "============================================" -ForegroundColor Green
Write-Host "Deployment i Spark Cluster në 10 VM" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Check if plink and pscp are available (PuTTY tools)
if (-not (Get-Command plink -ErrorAction SilentlyContinue)) {
    Write-Host "GABIM: 'plink' nuk u gjet. Ju lutem instaloni PuTTY tools." -ForegroundColor Red
    Write-Host "Shkarkoni nga: https://www.putty.org/" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command pscp -ErrorAction SilentlyContinue)) {
    Write-Host "GABIM: 'pscp' nuk u gjet. Ju lutem instaloni PuTTY tools." -ForegroundColor Red
    Write-Host "Shkarkoni nga: https://www.putty.org/" -ForegroundColor Yellow
    exit 1
}

# Function to copy files to VM
function Copy-FilesToVM {
    param($vm)
    
    Write-Host "Duke kopjuar dosjet ne $($vm.Name)..." -ForegroundColor Cyan
    
    # Create directory first
    Invoke-SSHCommand -vm $vm -command "mkdir -p /tmp/financial-analysis"
    
    # Copy entire project directory
    $pscpCmd = "pscp -r -P $($vm.SSHPort) -pw $($vm.Pass) -batch $projectPath\* $($vm.User)@${baseHost}:/tmp/financial-analysis/"
    Invoke-Expression $pscpCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Dosjet u kopjuan me sukses ne $($vm.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Deshtoi kopjimi ne $($vm.Name)" -ForegroundColor Red
    }
}

# Function to run command on VM
function Invoke-SSHCommand {
    param($vm, $command)
    
    $plinkCmd = "plink -ssh -P $($vm.SSHPort) -pw $($vm.Pass) -batch $($vm.User)@${baseHost} `"$command`""
    Invoke-Expression $plinkCmd
}

# Function to install Spark on VM
function Install-SparkOnVM {
    param($vm)
    
    Write-Host "Duke instaluar Spark ne $($vm.Name)..." -ForegroundColor Cyan
    
    # Move files to correct location
    Invoke-SSHCommand -vm $vm -command "sudo mkdir -p /opt/financial-analysis; sudo cp -r /tmp/financial-analysis/* /opt/financial-analysis/; sudo chown -R krenuser:krenuser /opt/financial-analysis"
    
    # Make install script executable and run it
    Invoke-SSHCommand -vm $vm -command "chmod +x /opt/financial-analysis/scripts/install_spark.sh; /opt/financial-analysis/scripts/install_spark.sh"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Spark u instalua me sukses ne $($vm.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] Deshtoi instalimi ne $($vm.Name)" -ForegroundColor Red
    }
}

# Main deployment logic
if (-not $InstallOnly) {
    Write-Host "Faza 1: Duke kopjuar dosjet në të gjitha VM-të..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($vm in $vms) {
        Copy-FilesToVM -vm $vm
        Start-Sleep -Seconds 2
    }
    
    Write-Host ""
    Write-Host "Kopjimi i dosjeve u përfundua!" -ForegroundColor Green
    Write-Host ""
}

if (-not $CopyOnly) {
    Write-Host "Faza 2: Duke instaluar Spark në të gjitha VM-të..." -ForegroundColor Yellow
    Write-Host "Kjo mund të zgjasë 10-15 minuta..." -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($vm in $vms) {
        Install-SparkOnVM -vm $vm
        Start-Sleep -Seconds 5
    }
    
    Write-Host ""
    Write-Host "Instalimi i Spark u përfundua!" -ForegroundColor Green
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Green
Write-Host "Deployment u përfundua me sukses!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Hapat e ardhshëm:" -ForegroundColor Cyan
Write-Host "1. Nisni cluster: .\scripts\start_cluster.ps1" -ForegroundColor White
Write-Host "2. Verifikoni statusin: .\scripts\check_cluster.ps1" -ForegroundColor White
Write-Host "3. Nisni aplikacionin: .\scripts\start_application.ps1" -ForegroundColor White
Write-Host ""
