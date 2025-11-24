#!/bin/bash
# Fix Spark permissions and start workers

echo "=========================================="
echo "Fixing Spark Permissions and Starting Workers"
echo "=========================================="
echo ""

# Fix /tmp/spark permissions
echo "Step 1: Fixing /tmp/spark permissions..."
sudo mkdir -p /tmp/spark
sudo chmod 777 /tmp/spark
sudo chown -R krenuser:krenuser /tmp/spark
echo "✓ Permissions fixed"
echo ""

# Fix Spark local directory
echo "Step 2: Setting up Spark local directory..."
mkdir -p /opt/financial-analysis/spark-temp
chmod 755 /opt/financial-analysis/spark-temp
echo "✓ Spark temp directory created"
echo ""

# Update spark-defaults.conf to use custom temp directory
echo "Step 3: Configuring Spark to use custom temp directory..."
if ! grep -q "spark.local.dir" /opt/spark/conf/spark-defaults.conf 2>/dev/null; then
    echo "spark.local.dir /opt/financial-analysis/spark-temp" | sudo tee -a /opt/spark/conf/spark-defaults.conf
    echo "✓ Spark configuration updated"
else
    echo "✓ Spark already configured"
fi
echo ""

# Start workers on this machine (if it's a worker)
echo "Step 4: Checking if this is the master or worker..."
HOSTNAME=$(hostname)
if [[ $HOSTNAME == *"VM1"* ]] || [[ $(hostname -I | grep -c "10.0.0.4") -gt 0 ]]; then
    echo "This is the MASTER node - workers should be on other VMs"
    echo ""
    echo "To start workers on worker VMs, SSH to each and run:"
    echo "  /opt/spark/sbin/start-worker.sh spark://10.0.0.4:7077"
else
    echo "This appears to be a WORKER node"
    echo "Starting Spark worker..."
    /opt/spark/sbin/start-worker.sh spark://10.0.0.4:7077
    sleep 3
    if pgrep -f "org.apache.spark.deploy.worker.Worker" > /dev/null; then
        echo "✓ Worker started successfully"
    else
        echo "✗ Failed to start worker"
    fi
fi
echo ""

# Restart Spark Master with correct permissions
echo "Step 5: Restarting Spark Master..."
if pgrep -f "org.apache.spark.deploy.master.Master" > /dev/null; then
    /opt/spark/sbin/stop-master.sh
    sleep 2
fi
/opt/spark/sbin/start-master.sh
sleep 3

if pgrep -f "org.apache.spark.deploy.master.Master" > /dev/null; then
    echo "✓ Spark Master restarted"
else
    echo "✗ Failed to restart Spark Master"
fi
echo ""

echo "=========================================="
echo "Fix Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Wait 5-10 minutes for data collection"
echo "2. Check status: bash /opt/financial-analysis/scripts/check_spark_status.sh"
echo "3. Train ML models: bash /opt/financial-analysis/scripts/train_ml_models.sh"
