#!/bin/bash
# Script to check Spark cluster status and running applications

echo "=========================================="
echo "Spark Cluster Status"
echo "=========================================="
echo ""

# Check if Spark master is running
echo "Checking Spark Master..."
if pgrep -f "org.apache.spark.deploy.master.Master" > /dev/null; then
    echo "✓ Spark Master is RUNNING"
else
    echo "✗ Spark Master is NOT running"
    echo "  Start it with: /opt/spark/sbin/start-master.sh"
fi
echo ""

# Check Spark workers
echo "Checking Spark Workers..."
WORKER_COUNT=$(pgrep -f "org.apache.spark.deploy.worker.Worker" | wc -l)
if [ $WORKER_COUNT -gt 0 ]; then
    echo "✓ Found $WORKER_COUNT Spark Worker(s) running"
else
    echo "✗ No Spark Workers running"
    echo "  Start them with: /opt/spark/sbin/start-workers.sh"
fi
echo ""

# Check running Spark applications
echo "Running Spark Applications:"
SPARK_APPS=$(pgrep -f "SparkSubmit" | wc -l)
if [ $SPARK_APPS -gt 0 ]; then
    echo "✓ $SPARK_APPS Spark application(s) running"
    echo ""
    echo "Application details:"
    ps aux | grep SparkSubmit | grep -v grep | awk '{print "  - PID:", $2, "CMD:", $11, $12, $13, $14, $15}'
else
    echo "  No Spark applications currently running"
fi
echo ""

# Check dashboard
echo "Checking Dashboard..."
if pgrep -f "ultra_modern_dashboard.py" > /dev/null; then
    echo "✓ Dashboard is RUNNING"
    DASH_PID=$(pgrep -f "ultra_modern_dashboard.py")
    echo "  PID: $DASH_PID"
    echo "  URL: http://10.0.0.4:8050"
else
    echo "✗ Dashboard is NOT running"
    echo "  Start it with: nohup python3.9 /opt/financial-analysis/dashboard/ultra_modern_dashboard.py > /opt/financial-analysis/logs/dashboard.log 2>&1 &"
fi
echo ""

# Check data collector
echo "Checking Data Collector..."
if pgrep -f "advanced_collector.py" > /dev/null; then
    echo "✓ Data Collector is RUNNING"
    COLLECTOR_PID=$(pgrep -f "advanced_collector.py")
    echo "  PID: $COLLECTOR_PID"
else
    echo "✗ Data Collector is NOT running"
    echo "  Start it with: /opt/spark/bin/spark-submit --master spark://10.0.0.4:7077 /opt/financial-analysis/spark_apps/advanced_collector.py"
fi
echo ""

# Check if models exist
echo "Checking ML Models..."
if [ -d "/opt/financial-analysis/models" ]; then
    MODEL_COUNT=$(find /opt/financial-analysis/models -name "*.h5" -o -name "metadata" 2>/dev/null | wc -l)
    if [ $MODEL_COUNT -gt 0 ]; then
        echo "✓ ML Models found: $MODEL_COUNT model(s)"
    else
        echo "⚠ ML Models directory exists but no models found"
        echo "  Train models with: /opt/financial-analysis/scripts/train_ml_models.sh"
    fi
else
    echo "✗ ML Models directory not found"
    echo "  Train models with: /opt/financial-analysis/scripts/train_ml_models.sh"
fi
echo ""

# Spark UI URLs
echo "=========================================="
echo "Spark Web UIs:"
echo "=========================================="
echo "  Master UI:    http://10.0.0.4:8080"
echo "  Application:  http://10.0.0.4:4040 (when app is running)"
echo "  Dashboard:    http://10.0.0.4:8050"
echo ""
echo "Port Forwarding (from your local machine):"
echo "  ssh -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -L 4040:10.0.0.4:4040 -p 8022 krenuser@185.182.158.150"
echo ""
echo "Then access:"
echo "  Dashboard:      http://localhost:8050"
echo "  Spark Master:   http://localhost:8080"
echo "  Spark App:      http://localhost:4040"
echo "=========================================="
