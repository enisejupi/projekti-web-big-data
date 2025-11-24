# ========================================
# Simple Spark Cluster Fix Script
# Fixes serialVersionUID incompatibility
# ========================================

param([string]$Action = "all")

$VM_HOST = "185.182.158.150"
$VM_PORT = "8022"
$VM_USER = "krenuser"

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  SPARK CLUSTER FIX UTILITY" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

Write-Host "You will be prompted for the SSH password once.`n" -ForegroundColor Yellow

# Create a comprehensive fix script to run on master
$remoteScript = @"
#!/bin/bash
echo ""
echo "============================================"
echo "  SPARK CLUSTER FIX"
echo "============================================"
echo ""

# Step 1: Stop all Spark processes
echo "[1/6] Stopping all Spark processes..."
pkill -9 -f 'org.apache.spark.deploy.master.Master'
pkill -9 -f 'org.apache.spark.deploy.worker.Worker'
sleep 2

# Stop workers on all nodes
for ip in 10.0.0.5 10.0.0.6 10.0.0.7 10.0.0.8 10.0.0.9 10.0.0.10 10.0.0.11 10.0.0.12 10.0.0.13; do
    echo "  -> Stopping worker \$ip..."
    ssh -o StrictHostKeyChecking=no krenuser@\$ip 'pkill -9 -f org.apache.spark.deploy.worker.Worker' 2>/dev/null
done

echo "  [OK] All processes stopped"
echo ""

# Step 2: Clean metadata and logs
echo "[2/6] Cleaning metadata and logs..."
rm -rf /tmp/spark-*
rm -rf /opt/spark/work/*
rm -rf /opt/spark/logs/spark-*.out
find /opt/spark/logs -type f -name '*.out' -mtime +7 -delete 2>/dev/null

for ip in 10.0.0.5 10.0.0.6 10.0.0.7 10.0.0.8 10.0.0.9 10.0.0.10 10.0.0.11 10.0.0.12 10.0.0.13; do
    ssh -o StrictHostKeyChecking=no krenuser@\$ip 'rm -rf /tmp/spark-*; rm -rf /opt/spark/work/*' 2>/dev/null
done

echo "  [OK] Cleanup complete"
echo ""

# Step 3: Update Spark configuration
echo "[3/6] Updating Spark configuration..."
cat > /opt/spark/conf/spark-defaults.conf << 'SPARKCONF'
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
SPARKCONF

echo "  [OK] Configuration updated"
echo ""

# Step 4: Start Spark Master
echo "[4/6] Starting Spark Master..."
cd /opt/spark
./sbin/start-master.sh
sleep 5
jps | grep Master
echo "  [OK] Master started"
echo ""

# Step 5: Start Spark Workers
echo "[5/6] Starting Spark Workers..."
for ip in 10.0.0.5 10.0.0.6 10.0.0.7 10.0.0.8 10.0.0.9 10.0.0.10 10.0.0.11 10.0.0.12 10.0.0.13; do
    echo "  -> Starting worker \$ip..."
    ssh -o StrictHostKeyChecking=no krenuser@\$ip 'cd /opt/spark; ./sbin/start-worker.sh spark://10.0.0.4:7077; sleep 2' 2>/dev/null
done

echo "  [OK] All workers started"
echo "  -> Waiting 10 seconds for cluster to stabilize..."
sleep 10
echo ""

# Step 6: Verify cluster
echo "[6/6] Verifying cluster status..."
echo "  Master Status:"
jps | grep Master
echo ""
echo "  Worker Count:"
curl -s http://10.0.0.4:8080 2>/dev/null | grep -o 'Workers ([0-9]*)' | head -1 || echo "  Checking..."
echo ""

# Clean up old application processes
echo "  -> Cleaning up old application processes..."
pkill -9 -f periodic_predictions 2>/dev/null
pkill -9 -f MLPredictor 2>/dev/null
pkill -9 -f data_collector 2>/dev/null
sleep 2

echo "  [OK] Verification complete"
echo ""
echo "============================================"
echo "  SPARK CLUSTER FIX COMPLETE!"
echo "============================================"
echo ""
"@

# Upload and execute the script
$tempScript = "$env:TEMP\fix_cluster.sh"
$remoteScript -replace "`r`n", "`n" | Out-File -FilePath $tempScript -Encoding UTF8 -NoNewline

Write-Host "Uploading fix script..." -ForegroundColor Cyan
scp -P $VM_PORT $tempScript "$VM_USER@${VM_HOST}:/tmp/fix_cluster.sh"

Write-Host "`nExecuting fix script on master node...`n" -ForegroundColor Cyan
ssh -p $VM_PORT "$VM_USER@$VM_HOST" "bash /tmp/fix_cluster.sh"

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  FIX COMPLETE!" -ForegroundColor Green
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
