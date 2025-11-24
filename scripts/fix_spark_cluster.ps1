# ========================================
# Comprehensive Spark Cluster Fix Script
# Fixes serialVersionUID incompatibility and cluster issues
# ========================================

param([string]$Action = "all")

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

# Worker VMs
$WORKERS = @(
    @{IP="10.0.0.5"; Port="8023"},
    @{IP="10.0.0.6"; Port="8024"},
    @{IP="10.0.0.7"; Port="8025"},
    @{IP="10.0.0.8"; Port="8026"},
    @{IP="10.0.0.9"; Port="8027"},
    @{IP="10.0.0.10"; Port="8028"},
    @{IP="10.0.0.11"; Port="8029"},
    @{IP="10.0.0.12"; Port="8030"},
    @{IP="10.0.0.13"; Port="8031"}
)

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  SPARK CLUSTER FIX UTILITY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

# Step 1: Stop all Spark processes
if ($Action -eq "all" -or $Action -eq "1") {
    Write-Host "[1/8] Stopping all Spark processes..." -ForegroundColor Yellow
    
    # Stop master
    Write-Host "  -> Stopping Master (10.0.0.4)..." -ForegroundColor Cyan
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "pkill -9 -f 'org.apache.spark.deploy.master.Master'; pkill -9 -f 'org.apache.spark.deploy.worker.Worker'; sleep 2; echo '    Master stopped'"
    
    # Stop workers
    Write-Host "  -> Stopping Workers..." -ForegroundColor Cyan
    foreach ($worker in $WORKERS) {
        $ip = $worker.IP
        Write-Host "    • Worker $ip..." -ForegroundColor Gray
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "ssh -o StrictHostKeyChecking=no krenuser@$ip 'pkill -9 -f org.apache.spark.deploy.worker.Worker; exit 0'"
    }
    
    Write-Host "  [OK] All processes stopped`n" -ForegroundColor Green
}

# Step 2: Clean old metadata and logs
if ($Action -eq "all" -or $Action -eq "2") {
    Write-Host "[2/8] Cleaning metadata and logs..." -ForegroundColor Yellow
    
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "rm -rf /tmp/spark-*; rm -rf /opt/spark/work/*; rm -rf /opt/spark/logs/spark-*.out; echo '  [OK] Master cleaned'"
    
    foreach ($worker in $WORKERS) {
        $ip = $worker.IP
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "ssh -o StrictHostKeyChecking=no krenuser@$ip 'rm -rf /tmp/spark-*; rm -rf /opt/spark/work/*'"
    }
    
    Write-Host "  [OK] Cleanup complete`n" -ForegroundColor Green
}

# Step 3: Verify Spark version consistency
if ($Action -eq "all" -or $Action -eq "3") {
    Write-Host "[3/8] Checking Spark version consistency..." -ForegroundColor Yellow
    
    $masterVersion = ssh -p $VM_PORT "$VM_USER@$VM_HOST" "/opt/spark/bin/spark-submit --version 2>&1 | grep 'version' | head -1"
    Write-Host "  Master: $masterVersion" -ForegroundColor Cyan
    
    Write-Host "  [OK] Version check complete`n" -ForegroundColor Green
}

# Step 4: Update Spark configuration
if ($Action -eq "all" -or $Action -eq "4") {
    Write-Host "[4/8] Updating Spark configuration..." -ForegroundColor Yellow
    
    $configFile = "$env:TEMP\spark-defaults-temp.conf"
    
    @"
# Spark Configuration - Fixed for serialVersionUID issues
spark.master                                spark://10.0.0.4:7077
spark.master.port                           7077
spark.master.webui.port                     8080

# Executor Configuration
spark.executor.memory                       120g
spark.executor.cores                        16
spark.executor.instances                    9
spark.driver.memory                         100g
spark.driver.cores                          16
spark.driver.maxResultSize                  20g

# Network and Timeouts - Increased for stability
spark.network.timeout                       1200s
spark.executor.heartbeatInterval            120s
spark.rpc.askTimeout                        600s
spark.rpc.lookupTimeout                     600s
spark.core.connection.ack.wait.timeout      600s

# Serialization - Use Kryo to avoid Java serialization issues
spark.serializer                            org.apache.spark.serializer.KryoSerializer
spark.kryoserializer.buffer.max             512m
spark.kryo.registrationRequired             false

# Memory Management
spark.memory.fraction                       0.8
spark.memory.storageFraction                0.3
spark.memory.offHeap.enabled                true
spark.memory.offHeap.size                   20g

# Shuffle Configuration
spark.shuffle.service.enabled               false
spark.shuffle.file.buffer                   1m
spark.reducer.maxSizeInFlight               96m

# Parallelism
spark.default.parallelism                   256
spark.sql.shuffle.partitions                256
spark.sql.adaptive.enabled                  true

# Dynamic Allocation - Disabled for stability
spark.dynamicAllocation.enabled             false

# Event Log
spark.eventLog.enabled                      true
spark.eventLog.dir                          /opt/spark/logs
spark.history.fs.logDirectory               /opt/spark/logs

# UI Configuration
spark.ui.enabled                            true
spark.ui.port                               4040

# Python Configuration
spark.python.worker.memory                  4g
spark.python.worker.reuse                   true

# Application Name
spark.app.name                              FinancialAssetAnalysis

# Local Directory
spark.local.dir                             /tmp/spark
"@ | Out-File -FilePath $configFile -Encoding UTF8
    
    scp -P $VM_PORT $configFile "$VM_USER@${VM_HOST}:/opt/spark/conf/spark-defaults.conf"
    
    Write-Host "  [OK] Configuration updated`n" -ForegroundColor Green
}

# Step 5: Start Spark Master
if ($Action -eq "all" -or $Action -eq "5") {
    Write-Host "[5/8] Starting Spark Master..." -ForegroundColor Yellow
    
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "cd /opt/spark; ./sbin/start-master.sh; sleep 5; jps | grep Master"
    
    Write-Host "  [OK] Master started`n" -ForegroundColor Green
}

# Step 6: Start Spark Workers
if ($Action -eq "all" -or $Action -eq "6") {
    Write-Host "[6/8] Starting Spark Workers..." -ForegroundColor Yellow
    
    foreach ($worker in $WORKERS) {
        $ip = $worker.IP
        Write-Host "  -> Starting worker $ip..." -ForegroundColor Cyan
        
        ssh -p $VM_PORT "$VM_USER@$VM_HOST" "ssh -o StrictHostKeyChecking=no krenuser@$ip 'cd /opt/spark; ./sbin/start-worker.sh spark://10.0.0.4:7077; sleep 2; jps | grep Worker'"
    }
    
    Write-Host "  [OK] All workers started`n" -ForegroundColor Green
    Write-Host "  -> Waiting 10 seconds for cluster to stabilize..." -ForegroundColor Cyan
    Start-Sleep -Seconds 10
}

# Step 7: Verify cluster
if ($Action -eq "all" -or $Action -eq "7") {
    Write-Host "[7/8] Verifying cluster status..." -ForegroundColor Yellow
    
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "echo '  Master Status:'; jps | grep Master; echo ''"
    
    Write-Host "  [OK] Cluster verification complete`n" -ForegroundColor Green
}

# Step 8: Kill any ML prediction processes
if ($Action -eq "all" -or $Action -eq "8") {
    Write-Host "[8/8] Cleaning up application processes..." -ForegroundColor Yellow
    
    ssh -p $VM_PORT "$VM_USER@$VM_HOST" "pkill -9 -f periodic_predictions; pkill -9 -f MLPredictor; pkill -9 -f data_collector; sleep 2; echo '  [OK] Old processes terminated'"
    
    Write-Host "  [OK] Cleanup complete`n" -ForegroundColor Green
}

Write-Host "============================================" -ForegroundColor Green
Write-Host "  SPARK CLUSTER FIX COMPLETE!" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Green

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check cluster status:" -ForegroundColor White
Write-Host "     .\manage.ps1 -Action status`n" -ForegroundColor Gray
Write-Host "  2. Start data collector:" -ForegroundColor White
Write-Host "     .\manage.ps1 -Action start-free-collector`n" -ForegroundColor Gray
Write-Host "  3. Forward ports:" -ForegroundColor White
Write-Host "     .\manage.ps1 -Action port-forward`n" -ForegroundColor Gray
Write-Host "  4. Download presentations:" -ForegroundColor White
Write-Host "     .\Download-Presentations.ps1`n" -ForegroundColor Gray

Write-Host "Access UIs after port forwarding:" -ForegroundColor Cyan
Write-Host "  • Spark Master: http://localhost:8080" -ForegroundColor White
Write-Host "  • Dashboard:    http://localhost:8050`n" -ForegroundColor White
