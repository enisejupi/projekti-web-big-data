# ========================================
# Complete Setup Script
# Fixes Spark, downloads presentations, forwards ports
# ========================================

param(
    [switch]$SkipSparkFix,
    [switch]$SkipDownload,
    [switch]$PortForwardOnly
)

$ErrorActionPreference = "Continue"

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "  COMPLETE FINANCIAL ANALYSIS SETUP" -ForegroundColor Cyan
Write-Host "================================================`n" -ForegroundColor Cyan

# Step 1: Fix Spark Cluster
if (-not $SkipSparkFix -and -not $PortForwardOnly) {
    Write-Host "[STEP 1] Fixing Spark Cluster..." -ForegroundColor Yellow
    Write-Host "This will restart the entire cluster to fix serialization issues.`n" -ForegroundColor Gray
    
    & "$PSScriptRoot\fix_spark_cluster.ps1" -Action all
    
    Write-Host "`nWaiting 15 seconds for cluster to fully stabilize...`n" -ForegroundColor Cyan
    Start-Sleep -Seconds 15
} else {
    Write-Host "[STEP 1] Skipped - Spark cluster fix`n" -ForegroundColor Gray
}

# Step 2: Start Data Collector
if (-not $PortForwardOnly) {
    Write-Host "[STEP 2] Starting Data Collector..." -ForegroundColor Yellow
    Write-Host "This will start collecting financial data.`n" -ForegroundColor Gray
    
    & "$PSScriptRoot\manage.ps1" -Action start-free-collector
    
    Write-Host "`n"
} else {
    Write-Host "[STEP 2] Skipped - Data collector`n" -ForegroundColor Gray
}

# Step 3: Download Presentations
if (-not $SkipDownload -and -not $PortForwardOnly) {
    Write-Host "[STEP 3] Downloading Presentations..." -ForegroundColor Yellow
    Write-Host "Presentations will be saved to your Desktop.`n" -ForegroundColor Gray
    
    & "$PSScriptRoot\Download-Presentations.ps1"
    
    Write-Host "`n"
} else {
    Write-Host "[STEP 3] Skipped - Presentation download`n" -ForegroundColor Gray
}

# Step 4: Show Port Forwarding Instructions
Write-Host "[STEP 4] Port Forwarding Setup" -ForegroundColor Yellow
Write-Host "================================================`n" -ForegroundColor Cyan

Write-Host "To access the services, run port forwarding:" -ForegroundColor White
Write-Host "  .\manage.ps1 -Action port-forward`n" -ForegroundColor Cyan

Write-Host "This will forward:" -ForegroundColor White
Write-Host "  • Dashboard:       http://localhost:8050" -ForegroundColor Green
Write-Host "  • Spark Master UI: http://localhost:8080" -ForegroundColor Green
Write-Host "  • Spark App UI:    http://localhost:4040`n" -ForegroundColor Green

$response = Read-Host "Start port forwarding now? (y/n)"

if ($response -eq "y" -or $response -eq "Y" -or $PortForwardOnly) {
    Write-Host "`nStarting port forwarding..." -ForegroundColor Yellow
    Write-Host "Keep this terminal window open!" -ForegroundColor Red
    Write-Host "Press Ctrl+C to stop port forwarding when done.`n" -ForegroundColor Yellow
    
    Start-Sleep -Seconds 2
    
    & "$PSScriptRoot\manage.ps1" -Action port-forward
} else {
    Write-Host "`nPort forwarding skipped. Run manually when needed:" -ForegroundColor Yellow
    Write-Host "  .\manage.ps1 -Action port-forward`n" -ForegroundColor Gray
}

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "  SETUP COMPLETE!" -ForegroundColor Green
Write-Host "================================================`n" -ForegroundColor Green

Write-Host "Quick Reference:" -ForegroundColor Cyan
Write-Host "  Check status:    .\manage.ps1 -Action status" -ForegroundColor White
Write-Host "  Check data:      .\manage.ps1 -Action check-data" -ForegroundColor White
Write-Host "  Generate report: .\manage.ps1 -Action generate-presentation" -ForegroundColor White
Write-Host "  Port forward:    .\manage.ps1 -Action port-forward`n" -ForegroundColor White
