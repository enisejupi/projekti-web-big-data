#!/bin/bash
# Cron job për parashikime periodike
# Shto në crontab: */10 * * * * /opt/financial-analysis/scripts/run_periodic_predictions.sh

cd /opt/financial-analysis

/opt/spark/bin/spark-submit \
  --master spark://10.0.0.4:7077 \
  --executor-memory 130g \
  --driver-memory 120g \
  --executor-cores 16 \
  --total-executor-cores 144 \
  spark_apps/periodic_predictions.py

echo "Parashikimet u përditësuan: $(date)" >> /opt/financial-analysis/logs/cron.log
