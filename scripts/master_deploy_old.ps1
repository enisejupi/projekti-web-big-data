# PowerShell Master Script - All-in-One Deployment and Execution
# Ekzekuton të gjithë procesin: test, deploy, start cluster, start app

param(
    [switch]$SkipTest,
    [switch]$SkipDeploy,
    [switch]$SkipCluster,
    [switch]$Help
)

$ErrorActionPreference = "Continue"

if ($Help) {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "     MASTER SCRIPT - Financial Asset Analysis System           " -ForegroundColor Cyan
    Write-Host "              Apache Spark + Machine Learning                  " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host @"

Usage:
    .\scripts\master_deploy.ps1 [options]

Options:
    -SkipTest     Skip VM connection test
    -SkipDeploy   Skip deployment - use if already deployed
    -SkipCluster  Skip cluster start - use if already running
    -Help         Show this help message

Examples:
    Full deployment:
        .\scripts\master_deploy.ps1

    Only start application - if already deployed:
        .\scripts\master_deploy.ps1 -SkipTest -SkipDeploy -SkipCluster

"@
    exit 0
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "                   MASTER DEPLOYMENT                            " -ForegroundColor Cyan
Write-Host "     Complete Setup for Financial Analysis System               " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Step 1: Test Connection
if (-not $SkipTest) {
    Write-Host "`n[STEP 1/4] Testing VM Connectivity..." -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Gray
    
    & "$PSScriptRoot\test_connection.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Connection test failed. Please check VMs." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`n✓ Connection test passed!" -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "`n[STEP 1/4] Skipping connection test..." -ForegroundColor Yellow
}

# Step 2: Deploy to VMs
if (-not $SkipDeploy) {
    Write-Host "`n[STEP 2/4] Deploying to VMs..." -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Gray
    Write-Host "This will take 15-20 minutes..." -ForegroundColor Cyan
    Write-Host ""
    
    & "$PSScriptRoot\deploy_all.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Deployment failed." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`n✓ Deployment completed!" -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "`n[STEP 2/4] Skipping deployment..." -ForegroundColor Yellow
}

# Step 3: Start Cluster
if (-not $SkipCluster) {
    Write-Host "`n[STEP 3/4] Starting Spark Cluster..." -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Gray
    
    & "$PSScriptRoot\start_cluster.ps1"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Cluster start failed." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "`n✓ Cluster started!" -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "`n[STEP 3/4] Skipping cluster start..." -ForegroundColor Yellow
}

# Step 4: Start Application
Write-Host "`n[STEP 4/4] Starting Application..." -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Gray
Write-Host "This will run for 3.5 days - 84 hours..." -ForegroundColor Cyan
Write-Host ""

& "$PSScriptRoot\start_application.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nApplication start failed." -ForegroundColor Red
    exit 1
}

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "           ALL STEPS COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Setup Duration: $($duration.TotalMinutes.ToString('F1')) minutes" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
Write-Host ""
Write-Host "1. Setup Port Forwarding:" -ForegroundColor Cyan
Write-Host "   Open a NEW terminal and run:" -ForegroundColor White
Write-Host ""
Write-Host "   ssh -L 8050:10.0.0.4:8050 -L 9090:10.0.0.4:9090 -p 8022 krenuser@185.182.158.150" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Password: jh87qLXHzFGt6gkb9ukV" -ForegroundColor White
Write-Host ""
Write-Host "2. Access Dashboard:" -ForegroundColor Cyan
Write-Host "   Open browser: http://localhost:8050" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. View Spark UI:" -ForegroundColor Cyan
Write-Host "   Open browser: http://localhost:9090" -ForegroundColor Yellow
Write-Host ""
Write-Host "4. Monitor Progress:" -ForegroundColor Cyan
Write-Host "   .\scripts\check_cluster.ps1" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. View Logs - via SSH:" -ForegroundColor Cyan
Write-Host "   ssh -p 8022 krenuser@185.182.158.150" -ForegroundColor Yellow
Write-Host "   tail -f /opt/financial-analysis/logs/*.log" -ForegroundColor Yellow
Write-Host ""
Write-Host "================================================================" -ForegroundColor Gray
Write-Host ""
Write-Host "System Status:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
Write-Host "  Spark Cluster:   Running - 1 Master + 9 Workers" -ForegroundColor Green
Write-Host "  Data Collector:  Running in background" -ForegroundColor Green
Write-Host "  ML Predictor:    Will run after 30 min" -ForegroundColor Green
Write-Host "  Dashboard:       Running on port 8050" -ForegroundColor Green
Write-Host "  Spark UI:        Running on port 9090" -ForegroundColor Green
Write-Host "  Duration:        84 hours - 3.5 days" -ForegroundColor Green
Write-Host "  Target Accuracy: 90%+" -ForegroundColor Green
Write-Host ""
Write-Host "================================================================" -ForegroundColor Gray
Write-Host ""
Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "----------------------------------------------------------------" -ForegroundColor Gray
Write-Host "  - Do NOT close this window" -ForegroundColor Red
Write-Host "  - Keep your computer connected to internet" -ForegroundColor Red
Write-Host "  - Application will run for 3.5 days" -ForegroundColor Yellow
Write-Host "  - Dashboard updates automatically every 30 seconds" -ForegroundColor White
Write-Host "  - Data collection happens every 5 minutes" -ForegroundColor White
Write-Host ""
Write-Host "To stop everything:" -ForegroundColor Yellow
Write-Host "    .\scripts\stop_application.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Gray
Write-Host ""
Write-Host "Good luck with your project!" -ForegroundColor Green
Write-Host ""
