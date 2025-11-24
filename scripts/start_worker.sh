#!/bin/bash
# Start Spark worker and connect to master

MASTER_URL="spark://10.0.0.4:7077"

echo "=========================================="
echo "Starting Spark Worker"
echo "=========================================="
echo ""

# Check if worker is already running
if pgrep -f "org.apache.spark.deploy.worker.Worker" > /dev/null; then
    echo "⚠ Worker already running"
    echo "Stopping existing worker..."
    /opt/spark/sbin/stop-worker.sh
    sleep 3
fi

# Fix permissions
echo "Fixing permissions..."
sudo mkdir -p /tmp/spark
sudo chmod 777 /tmp/spark
sudo chown -R krenuser:krenuser /tmp/spark 2>/dev/null || true

mkdir -p /opt/financial-analysis/spark-temp
chmod 755 /opt/financial-analysis/spark-temp

# Start worker
echo "Starting worker connecting to: $MASTER_URL"
/opt/spark/sbin/start-worker.sh $MASTER_URL

sleep 5

# Verify
if pgrep -f "org.apache.spark.deploy.worker.Worker" > /dev/null; then
    WORKER_PID=$(pgrep -f "org.apache.spark.deploy.worker.Worker")
    echo ""
    echo "✓ Worker started successfully!"
    echo "  PID: $WORKER_PID"
    echo "  Master: $MASTER_URL"
    echo ""
    echo "Check status at: http://10.0.0.4:8080"
else
    echo ""
    echo "✗ Failed to start worker"
    echo "Check logs at: /opt/spark/logs/"
fi
