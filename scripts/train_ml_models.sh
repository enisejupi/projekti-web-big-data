#!/bin/bash
# Script to train ML models on Spark cluster
# Run this initially to train the models, then use periodic_predictions for updates

echo "=========================================="
echo "Training ML Models on Spark Cluster"
echo "=========================================="

cd /opt/financial-analysis

# Check if data exists
if [ ! -d "/opt/financial-analysis/data/raw" ] || [ -z "$(ls -A /opt/financial-analysis/data/raw/*.parquet 2>/dev/null)" ]; then
    echo "ERROR: No training data found in /opt/financial-analysis/data/raw/"
    echo "Please run the data collector first!"
    exit 1
fi

# Create directories if they don't exist
mkdir -p /opt/financial-analysis/models
mkdir -p /opt/financial-analysis/data/predictions
mkdir -p /opt/financial-analysis/logs

echo "Submitting ML training job to Spark..."

# Submit the training job
/opt/spark/bin/spark-submit \
  --master spark://10.0.0.4:7077 \
  --executor-memory 130g \
  --driver-memory 120g \
  --executor-cores 16 \
  --total-executor-cores 144 \
  --conf spark.executor.memoryOverhead=10g \
  --conf spark.driver.memoryOverhead=10g \
  --conf spark.sql.adaptive.enabled=true \
  --conf spark.sql.adaptive.coalescePartitions.enabled=true \
  --py-files /opt/financial-analysis/ml_models/predictor.py \
  /opt/financial-analysis/ml_models/predictor.py

if [ $? -eq 0 ]; then
    echo "=========================================="
    echo "✓ ML Models trained successfully!"
    echo "=========================================="
    echo "Models saved in: /opt/financial-analysis/models/"
    echo ""
    echo "You can now:"
    echo "  1. View predictions in the dashboard at http://10.0.0.4:8050/ml"
    echo "  2. Run periodic predictions with: /opt/financial-analysis/scripts/run_periodic_predictions.sh"
    echo ""
else
    echo "=========================================="
    echo "✗ ML Training failed!"
    echo "=========================================="
    echo "Check logs at: /opt/financial-analysis/logs/ml_predictor.log"
    exit 1
fi
