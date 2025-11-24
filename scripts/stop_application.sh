#!/bin/bash
# Stop all Financial Analysis services

echo "=========================================="
echo "Stopping All Services"
echo "=========================================="
echo ""

# Stop dashboard
echo "Stopping Dashboard..."
if pgrep -f "ultra_modern_dashboard.py" > /dev/null; then
    pkill -f "ultra_modern_dashboard.py"
    echo "✓ Dashboard stopped"
else
    echo "  Dashboard not running"
fi

# Stop data collector
echo ""
echo "Stopping Data Collector..."
if pgrep -f "advanced_collector.py" > /dev/null; then
    pkill -f "advanced_collector.py"
    echo "✓ Data Collector stopped"
else
    echo "  Data Collector not running"
fi

# Stop ML predictions
echo ""
echo "Stopping ML Predictions..."
if pgrep -f "periodic_predictions.py" > /dev/null; then
    pkill -f "periodic_predictions.py"
    echo "✓ ML Predictions stopped"
else
    echo "  ML Predictions not running"
fi

# Stop any other Spark jobs
echo ""
echo "Stopping Spark Jobs..."
if pgrep -f "SparkSubmit" > /dev/null; then
    pkill -f "SparkSubmit"
    echo "✓ Spark jobs stopped"
else
    echo "  No Spark jobs running"
fi

# Stop Spark Master (optional - comment out if you want to keep it running)
# echo ""
# echo "Stopping Spark Master..."
# if [ -f "/opt/spark/sbin/stop-master.sh" ]; then
#     /opt/spark/sbin/stop-master.sh
#     echo "✓ Spark Master stopped"
# fi

echo ""
echo "=========================================="
echo "All services stopped"
echo "=========================================="
echo ""
echo "To start again, run:"
echo "  bash /opt/financial-analysis/scripts/master_start_all.sh"
