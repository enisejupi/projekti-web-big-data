# Simple script to check status and train ML on the VM

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("status", "train", "fix-workers")]
    [string]$Action = "status"
)

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Financial Analysis - Quick Actions" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

switch ($Action) {
    "status" {
        Write-Host "Checking system status...`n" -ForegroundColor Yellow
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "bash /opt/financial-analysis/scripts/check_spark_status.sh"
    }
    
    "train" {
        Write-Host "Training ML models...`n" -ForegroundColor Yellow
        Write-Host "This will take 10-15 minutes. Please wait...`n" -ForegroundColor Gray
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "bash /opt/financial-analysis/scripts/train_ml_models.sh"
    }
    
    "fix-workers" {
        Write-Host "Fixing permissions and starting workers...`n" -ForegroundColor Yellow
        
        # Fix master
        Write-Host "Fixing master VM..." -ForegroundColor Cyan
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" @"
sudo mkdir -p /tmp/spark
sudo chmod 777 /tmp/spark
sudo chown -R krenuser:krenuser /tmp/spark
mkdir -p /opt/financial-analysis/spark-temp
/opt/spark/sbin/stop-master.sh
sleep 2
/opt/spark/sbin/start-master.sh
"@
        
        Write-Host "`n[OK] Master fixed`n" -ForegroundColor Green
        
        # Start workers on all worker VMs
        Write-Host "Starting workers on all VMs..." -ForegroundColor Cyan
        
        $workers = @(8023, 8024, 8025, 8026, 8027, 8028, 8029, 8030, 8031)
        
        foreach ($port in $workers) {
            Write-Host "  Starting worker on VM (port $port)..." -ForegroundColor Gray
            ssh -p $port "$VM_USER@$VM_HOST" @"
sudo mkdir -p /tmp/spark
sudo chmod 777 /tmp/spark
/opt/spark/sbin/stop-worker.sh 2>/dev/null
sleep 1
/opt/spark/sbin/start-worker.sh spark://10.0.0.4:7077
"@ 2>&1 | Out-Null
        }
        
        Write-Host "`n[OK] All workers started`n" -ForegroundColor Green
        Write-Host "Checking status..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "bash /opt/financial-analysis/scripts/check_spark_status.sh"
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  .\quick_action.ps1 -Action status        # Check system" -ForegroundColor Gray
Write-Host "  .\quick_action.ps1 -Action fix-workers   # Fix & start workers" -ForegroundColor Gray
Write-Host "  .\quick_action.ps1 -Action train         # Train ML models" -ForegroundColor Gray
Write-Host "========================================`n" -ForegroundColor Cyan
