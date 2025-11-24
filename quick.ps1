# Quick Commands Helper
# Use this from the root directory: C:\Users\Lenovo\projekti-web-info

param([string]$Action)

$ScriptDir = "C:\Users\Lenovo\projekti-web-info\scripts"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

switch ($Action) {
    "check-data" {
        Write-Host "  Checking Data Status" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        ssh -p 8022 krenuser@185.182.158.150 @"
echo "=== SQLite Database ==="
ls -lh /opt/financial-analysis/data/market_data.db 2>/dev/null || echo "No database file"
echo ""
echo "=== Parquet Files ==="
ls -lh /opt/financial-analysis/data/raw/*.parquet 2>/dev/null || echo "No parquet files"
echo ""
echo "=== Active Collectors ==="
ps aux | grep free_api_collector | grep -v grep | wc -l | xargs echo "Running collectors:"
echo ""
echo "=== Recent Log Activity ==="
tail -5 /opt/financial-analysis/logs/free_api_collector.log 2>/dev/null || echo "No logs"
"@
    }
    
    "generate-presentation" {
        Write-Host "  Generating Presentation" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        ssh -p 8022 krenuser@185.182.158.150 "cd /opt/financial-analysis/scripts && python3 generate_presentation.py"
    }
    
    "run-predictions" {
        Write-Host "  Running ML Predictions" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        ssh -p 8022 krenuser@185.182.158.150 "cd /opt/financial-analysis/spark_apps && python3 periodic_predictions.py"
    }
    
    "status" {
        Write-Host "  System Status" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        & "$ScriptDir\manage.ps1" -Action status
    }
    
    "port-forward" {
        Write-Host "  Starting Port Forwarding" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        & "$ScriptDir\manage.ps1" -Action port-forward
    }
    
    "start-collector" {
        Write-Host "  Starting Data Collector" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        & "$ScriptDir\manage.ps1" -Action start-free-collector
    }
    
    "logs-collector" {
        Write-Host "  Collector Logs (live)" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        ssh -p 8022 krenuser@185.182.158.150 "tail -f /opt/financial-analysis/logs/free_api_collector.log"
    }
    
    "logs-ml" {
        Write-Host "  ML Prediction Logs" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        ssh -p 8022 krenuser@185.182.158.150 "tail -50 /opt/financial-analysis/logs/periodic_predictions.log"
    }
    
    default {
        Write-Host "  Quick Commands" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage from root directory:" -ForegroundColor Yellow
        Write-Host "  .\quick.ps1 check-data" -ForegroundColor White
        Write-Host "  .\quick.ps1 generate-presentation" -ForegroundColor White
        Write-Host "  .\quick.ps1 run-predictions" -ForegroundColor White
        Write-Host "  .\quick.ps1 status" -ForegroundColor White
        Write-Host "  .\quick.ps1 port-forward" -ForegroundColor White
        Write-Host "  .\quick.ps1 start-collector" -ForegroundColor White
        Write-Host "  .\quick.ps1 logs-collector" -ForegroundColor White
        Write-Host "  .\quick.ps1 logs-ml" -ForegroundColor White
        Write-Host ""
        Write-Host "OR navigate to scripts folder:" -ForegroundColor Yellow
        Write-Host "  cd scripts" -ForegroundColor White
        Write-Host "  .\manage.ps1 -Action check-data" -ForegroundColor White
        Write-Host ""
    }
}

Write-Host ""
