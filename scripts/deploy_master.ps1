# PowerShell script to deploy and manage the Financial Analysis system
# Run this from your Windows machine

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("deploy", "status", "logs", "train-ml", "stop", "restart", "forward-ports")]
    [string]$Action = "status"
)

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"
$VM_PASS = "jh87qLXHzFGt6gkb9ukV"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Financial Analysis - Remote Management" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

function Invoke-SSHCommand {
    param([string]$Command)
    
    # Using plink from PuTTY (if available) or ssh
    if (Get-Command plink -ErrorAction SilentlyContinue) {
        echo y | plink -ssh -P $VM_PORT -pw $VM_PASS "$VM_USER@$VM_HOST" $Command
    } else {
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" $Command
    }
}

function Copy-ScriptToVM {
    param([string]$LocalPath, [string]$RemotePath)
    
    if (Get-Command pscp -ErrorAction SilentlyContinue) {
        echo y | pscp -P $VM_PORT -pw $VM_PASS $LocalPath "$VM_USER@${VM_HOST}:${RemotePath}"
    } else {
        scp -P $VM_PORT $LocalPath "$VM_USER@${VM_HOST}:${RemotePath}"
    }
}

switch ($Action) {
    "deploy" {
        Write-Host "Deploying to Master VM..." -ForegroundColor Yellow
        Write-Host ""
        
        # Copy all scripts
        Write-Host "Copying scripts..." -ForegroundColor Gray
        $scriptsPath = Join-Path $PSScriptRoot ".."
        
        # Make scripts directory
        Invoke-SSHCommand "mkdir -p /opt/financial-analysis/scripts"
        
        # Copy individual scripts
        Copy-ScriptToVM (Join-Path $PSScriptRoot "master_start_all.sh") "/opt/financial-analysis/scripts/master_start_all.sh"
        Copy-ScriptToVM (Join-Path $PSScriptRoot "train_ml_models.sh") "/opt/financial-analysis/scripts/train_ml_models.sh"
        Copy-ScriptToVM (Join-Path $PSScriptRoot "check_spark_status.sh") "/opt/financial-analysis/scripts/check_spark_status.sh"
        Copy-ScriptToVM (Join-Path $PSScriptRoot "run_periodic_predictions.sh") "/opt/financial-analysis/scripts/run_periodic_predictions.sh"
        Copy-ScriptToVM (Join-Path $PSScriptRoot "stop_application.sh") "/opt/financial-analysis/scripts/stop_application.sh"
        
        # Copy dashboard
        Write-Host "Copying dashboard..." -ForegroundColor Gray
        Invoke-SSHCommand "mkdir -p /opt/financial-analysis/dashboard"
        Copy-ScriptToVM (Join-Path $scriptsPath "dashboard\ultra_modern_dashboard.py") "/opt/financial-analysis/dashboard/ultra_modern_dashboard.py"
        
        # Copy ML models
        Write-Host "Copying ML models..." -ForegroundColor Gray
        Invoke-SSHCommand "mkdir -p /opt/financial-analysis/ml_models"
        Copy-ScriptToVM (Join-Path $scriptsPath "ml_models\predictor.py") "/opt/financial-analysis/ml_models/predictor.py"
        
        # Copy Spark apps
        Write-Host "Copying Spark apps..." -ForegroundColor Gray
        Invoke-SSHCommand "mkdir -p /opt/financial-analysis/spark_apps"
        Copy-ScriptToVM (Join-Path $scriptsPath "spark_apps\advanced_collector.py") "/opt/financial-analysis/spark_apps/advanced_collector.py"
        Copy-ScriptToVM (Join-Path $scriptsPath "spark_apps\periodic_predictions.py") "/opt/financial-analysis/spark_apps/periodic_predictions.py"
        
        # Make scripts executable
        Write-Host "Setting permissions..." -ForegroundColor Gray
        Invoke-SSHCommand "chmod +x /opt/financial-analysis/scripts/*.sh"
        
        # Start everything
        Write-Host ""
        Write-Host "Starting services..." -ForegroundColor Yellow
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/master_start_all.sh"
        
        Write-Host ""
        Write-Host "✓ Deployment complete!" -ForegroundColor Green
    }
    
    "status" {
        Write-Host "Checking system status..." -ForegroundColor Yellow
        Write-Host ""
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/check_spark_status.sh"
    }
    
    "logs" {
        Write-Host "Fetching recent logs..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "=== Dashboard Logs ===" -ForegroundColor Cyan
        Invoke-SSHCommand "tail --lines=50 /opt/financial-analysis/logs/dashboard.log"
        Write-Host ""
        Write-Host "=== Collector Logs ===" -ForegroundColor Cyan
        Invoke-SSHCommand "tail --lines=50 /opt/financial-analysis/logs/collector.log"
    }
    
    "train-ml" {
        Write-Host "Training ML models..." -ForegroundColor Yellow
        Write-Host ""
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/train_ml_models.sh"
    }
    
    "stop" {
        Write-Host "Stopping all services..." -ForegroundColor Yellow
        Write-Host ""
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/stop_application.sh"
        Write-Host "✓ Services stopped" -ForegroundColor Green
    }
    
    "restart" {
        Write-Host "Restarting all services..." -ForegroundColor Yellow
        Write-Host ""
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/stop_application.sh"
        Start-Sleep -Seconds 3
        Invoke-SSHCommand "bash /opt/financial-analysis/scripts/master_start_all.sh"
    }
    
    "forward-ports" {
        Write-Host "Setting up SSH port forwarding..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This will forward the following ports:" -ForegroundColor Gray
        Write-Host "  - 8050 -> Dashboard" -ForegroundColor Gray
        Write-Host "  - 8080 -> Spark Master UI" -ForegroundColor Gray
        Write-Host "  - 4040 -> Spark Application UI" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Yellow
        Write-Host ""
        
        ssh -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -L 4040:10.0.0.4:4040 -p $VM_PORT "$VM_USER@$VM_HOST"
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Access URLs (with port forwarding):" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Dashboard:      http://localhost:8050" -ForegroundColor White
Write-Host "  Spark Master:   http://localhost:8080" -ForegroundColor White
Write-Host "  Spark App:      http://localhost:4040" -ForegroundColor White
Write-Host ""
Write-Host "Available Actions:" -ForegroundColor Cyan
Write-Host "  .\deploy_master.ps1 -Action deploy         # Deploy all files and start services" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action status         # Check system status" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action logs           # View recent logs" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action train-ml       # Train ML models" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action stop           # Stop all services" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action restart        # Restart all services" -ForegroundColor Gray
Write-Host "  .\deploy_master.ps1 -Action forward-ports  # Setup SSH tunnels" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
