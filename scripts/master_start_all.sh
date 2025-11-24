#!/bin/bash
# Comprehensive deployment script for Master VM (10.0.0.4)
# This script ensures all components are running

echo "=========================================="
echo "Financial Analysis - Master Deployment"
echo "=========================================="
echo "Starting all services on Master VM..."
echo ""

# Set environment
export SPARK_HOME=/opt/spark
export PATH=$SPARK_HOME/bin:$PATH
export PYSPARK_PYTHON=/usr/bin/python3.9

cd /opt/financial-analysis

# Create necessary directories
echo "Creating directories..."
mkdir -p /opt/financial-analysis/data/raw
mkdir -p /opt/financial-analysis/data/predictions
mkdir -p /opt/financial-analysis/models
mkdir -p /opt/financial-analysis/logs
mkdir -p /opt/financial-analysis/reports
echo "✓ Directories created"
echo ""

# Check if Spark Master is running
echo "Step 1: Starting Spark Master..."
if pgrep -f "org.apache.spark.deploy.master.Master" > /dev/null; then
    echo "✓ Spark Master already running"
else
    $SPARK_HOME/sbin/start-master.sh
    sleep 5
    if pgrep -f "org.apache.spark.deploy.master.Master" > /dev/null; then
        echo "✓ Spark Master started successfully"
    else
        echo "✗ Failed to start Spark Master"
        exit 1
    fi
fi
echo ""

# Check Spark Workers
echo "Step 2: Checking Spark Workers..."
WORKER_COUNT=$(pgrep -f "org.apache.spark.deploy.worker.Worker" | wc -l)
if [ $WORKER_COUNT -gt 0 ]; then
    echo "✓ $WORKER_COUNT Worker(s) connected"
else
    echo "⚠ No workers detected. Workers should be started on worker VMs."
    echo "  Run on each worker VM: $SPARK_HOME/sbin/start-worker.sh spark://10.0.0.4:7077"
fi
echo ""

# Kill any existing dashboard
echo "Step 3: Starting Dashboard..."
if pgrep -f "ultra_modern_dashboard.py" > /dev/null; then
    echo "Stopping existing dashboard..."
    pkill -f "ultra_modern_dashboard.py"
    sleep 2
fi

nohup python3.9 /opt/financial-analysis/dashboard/ultra_modern_dashboard.py > /opt/financial-analysis/logs/dashboard.log 2>&1 &
DASH_PID=$!
sleep 3

if pgrep -f "ultra_modern_dashboard.py" > /dev/null; then
    echo "✓ Dashboard started (PID: $DASH_PID)"
    echo "  URL: http://10.0.0.4:8050"
else
    echo "✗ Failed to start dashboard"
    echo "  Check logs: /opt/financial-analysis/logs/dashboard.log"
fi
echo ""

# Start data collector
echo "Step 4: Starting Data Collector..."
if pgrep -f "advanced_collector.py" > /dev/null; then
    echo "✓ Data Collector already running"
else
    nohup /opt/spark/bin/spark-submit \
        --master spark://10.0.0.4:7077 \
        --executor-memory 130g \
        --driver-memory 120g \
        --executor-cores 16 \
        --total-executor-cores 144 \
        --conf spark.executor.memoryOverhead=10g \
        --conf spark.driver.memoryOverhead=10g \
        /opt/financial-analysis/spark_apps/advanced_collector.py \
        > /opt/financial-analysis/logs/collector.log 2>&1 &
    
    COLLECTOR_PID=$!
    echo "✓ Data Collector started (PID: $COLLECTOR_PID)"
    echo "  This will collect market data continuously"
fi
echo ""

# Check if we should train ML models
echo "Step 5: Checking ML Models..."
if [ -d "/opt/financial-analysis/models/random_forest" ] && [ -d "/opt/financial-analysis/models/gradient_boosting" ]; then
    echo "✓ ML Models already trained"
    echo "  To retrain: bash /opt/financial-analysis/scripts/train_ml_models.sh"
else
    echo "⚠ ML Models not found"
    echo ""
    echo "ML models need training data first!"
    echo "Data collector is running and will gather data continuously."
    echo ""
    echo "IMPORTANT: Wait at least 10 minutes for data collection, then train models with:"
    echo "  bash /opt/financial-analysis/scripts/train_ml_models.sh"
    echo ""
fi
echo ""

# Setup cron for periodic predictions (if models exist)
echo "Step 6: Setting up Periodic Predictions..."
if [ -d "/opt/financial-analysis/models/random_forest" ]; then
    if ! crontab -l 2>/dev/null | grep -q "run_periodic_predictions.sh"; then
        echo "Adding cron job for periodic predictions..."
        (crontab -l 2>/dev/null; echo "*/10 * * * * /opt/financial-analysis/scripts/run_periodic_predictions.sh") | crontab -
        echo "✓ Cron job added (runs every 10 minutes)"
    else
        echo "✓ Cron job already configured"
    fi
else
    echo "⚠ Skipping cron setup (train models first)"
fi
echo ""

# Display status
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
echo ""

# Show what's running
/opt/financial-analysis/scripts/check_spark_status.sh

echo ""
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Access dashboard at: http://localhost:8050 (with port forwarding)"
echo "2. Monitor Spark at: http://localhost:8080 (with port forwarding)"
echo ""
echo "Port Forwarding Command (run on your local machine):"
echo "  ssh -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -L 4040:10.0.0.4:4040 -p 8022 krenuser@185.182.158.150"
echo ""
echo "Useful Commands:"
echo "  Check status:     bash /opt/financial-analysis/scripts/check_spark_status.sh"
echo "  Train ML models:  bash /opt/financial-analysis/scripts/train_ml_models.sh"
echo "  View logs:        tail -f /opt/financial-analysis/logs/dashboard.log"
echo "  Stop all:         bash /opt/financial-analysis/scripts/stop_application.sh"
echo "=========================================="
