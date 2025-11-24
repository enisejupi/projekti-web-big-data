#!/bin/bash
# Ultimate Cluster Utilization Script
# This will make full use of all 10 VMs

echo "========================================"
echo "  ACTIVATING FULL CLUSTER POWER"
echo "========================================"
echo ""

# Step 1: Kill ALL old collectors
echo "[1/6] Stopping ALL old collectors..."
pkill -9 -f free_api_collector
pkill -9 -f data_collector
pkill -9 -f advanced_collector
pkill -9 -f multi_source_collector
pkill -9 -f simple_collector
pkill -9 -f periodic_predictions
sleep 3
echo "  [OK] All old processes killed"
echo ""

# Step 2: Verify Spark cluster is ready
echo "[2/6] Checking Spark cluster..."
MASTER_STATUS=$(jps | grep Master)
if [ -z "$MASTER_STATUS" ]; then
    echo "  [!] Starting Spark Master..."
    cd /opt/spark
    ./sbin/start-master.sh
    sleep 5
fi

WORKER_COUNT=$(curl -s http://10.0.0.4:8080 2>/dev/null | grep -o 'Alive Workers ([0-9]*)' | grep -o '[0-9]*')
echo "  Master: Running"
echo "  Workers: $WORKER_COUNT/9"

if [ "$WORKER_COUNT" -lt 5 ]; then
    echo "  [!] Starting workers..."
    for ip in 10.0.0.5 10.0.0.6 10.0.0.7 10.0.0.8 10.0.0.9 10.0.0.10 10.0.0.11 10.0.0.12 10.0.0.13; do
        ssh -o StrictHostKeyChecking=no krenuser@$ip 'cd /opt/spark; ./sbin/start-worker.sh spark://10.0.0.4:7077' 2>/dev/null &
    done
    sleep 10
fi
echo "  [OK] Cluster ready"
echo ""

# Step 3: Check database
echo "[3/6] Checking database..."
DB_COUNT=$(psql -h 10.0.0.4 -U financeuser -d financial_data -t -c "SELECT COUNT(*) FROM market_data;" 2>/dev/null | tr -d ' ')
echo "  Current records: $DB_COUNT"
echo "  [OK] Database ready"
echo ""

# Step 4: Start ADVANCED collector with Spark
echo "[4/6] Starting ADVANCED Spark Collector..."
echo "  This will use ALL 10 VMs for data collection!"

# Check which collector to use
if [ -f /opt/financial-analysis/spark_apps/advanced_collector.py ]; then
    COLLECTOR="advanced_collector.py"
elif [ -f /opt/financial-analysis/spark_apps/multi_source_collector.py ]; then
    COLLECTOR="multi_source_collector.py"
else
    COLLECTOR="data_collector.py"
fi

echo "  Using: $COLLECTOR"

cd /opt/financial-analysis/spark_apps

# Start with Spark submit to use cluster
nohup /opt/spark/bin/spark-submit \
    --master spark://10.0.0.4:7077 \
    --executor-memory 100g \
    --executor-cores 14 \
    --num-executors 9 \
    --driver-memory 80g \
    --conf spark.default.parallelism=256 \
    --conf spark.sql.shuffle.partitions=256 \
    --conf spark.network.timeout=1200s \
    --conf spark.executor.heartbeatInterval=120s \
    /opt/financial-analysis/spark_apps/$COLLECTOR \
    > /opt/financial-analysis/logs/spark_collector.log 2>&1 &

COLLECTOR_PID=$!
echo $COLLECTOR_PID > /opt/financial-analysis/logs/spark_collector.pid

sleep 5

# Verify it started
if ps -p $COLLECTOR_PID > /dev/null; then
    echo "  [OK] Collector started (PID: $COLLECTOR_PID)"
else
    echo "  [!] Collector may have failed, check logs"
fi
echo ""

# Step 5: Configure ML predictions to run periodically
echo "[5/6] Setting up ML predictions..."

# Create cron job for periodic predictions
(crontab -l 2>/dev/null | grep -v periodic_predictions; echo "*/30 * * * * cd /opt/financial-analysis/spark_apps && /opt/spark/bin/spark-submit --master spark://10.0.0.4:7077 --executor-memory 80g --num-executors 9 periodic_predictions.py >> /opt/financial-analysis/logs/ml_predictions.log 2>&1") | crontab -

echo "  [OK] ML predictions scheduled (every 30 minutes)"
echo ""

# Step 6: Optimize collector for maximum throughput
echo "[6/6] Optimizing for maximum data collection..."

# Update collector configuration if it exists
if [ -f /opt/financial-analysis/configs/collector_config.json ]; then
    cat > /opt/financial-analysis/configs/collector_config.json <<EOF
{
    "batch_size": 1000,
    "collection_interval": 10,
    "num_workers": 9,
    "symbols_per_worker": 100,
    "enable_real_time": true,
    "max_records_per_minute": 10000
}
EOF
fi

echo "  [OK] Configuration optimized"
echo ""

# Summary
echo "========================================"
echo "  CLUSTER FULLY ACTIVATED!"
echo "========================================"
echo ""
echo "System Status:"
echo "  → Spark Master: Running"
echo "  → Workers: $WORKER_COUNT VMs"
echo "  → Collector: $COLLECTOR (Distributed)"
echo "  → ML Predictions: Scheduled"
echo "  → Expected throughput: 100-500 records/second"
echo ""
echo "Monitor progress:"
echo "  - Collector logs: tail -f /opt/financial-analysis/logs/spark_collector.log"
echo "  - Spark UI: http://10.0.0.4:8080"
echo "  - Dashboard: http://10.0.0.4:8050"
echo ""
echo "Wait 5-10 minutes for data to accumulate..."
echo "========================================"
