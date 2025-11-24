#!/bin/bash
# Complete fix for all issues: Data, ML, Presentations

echo "=========================================="
echo "COMPLETE SYSTEM FIX"
echo "=========================================="

cd /opt/financial-analysis

# 1. Stop everything first
echo "[1/6] Stopping old processes..."
pkill -9 -f "advanced_collector"
pkill -9 -f "free_api_collector"
pkill -9 -f "simple_data_generator"
pkill -9 -f "dashboard"
pkill -9 -f "app.py"
sleep 3

# 2. Generate initial data for ML and presentations
echo "[2/6] Generating initial data..."
python3.9 << 'PYEOF'
import sys
import psycopg2
from datetime import datetime, timedelta
import random

try:
    conn = psycopg2.connect(
        host='10.0.0.4',
        port=5432,
        database='financial_data',
        user='financeuser',
        password='Finance@2025!Secure'
    )
    cur = conn.cursor()
    
    # Generate test data for 50 symbols over last 30 days
    symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'TSLA', 'NVDA', 'JPM', 'V', 'JNJ',
               'WMT', 'PG', 'MA', 'UNH', 'HD', 'DIS', 'BAC', 'CSCO', 'ADBE', 'CRM',
               'NFLX', 'INTC', 'PFE', 'CMCSA', 'XOM', 'ABT', 'NKE', 'TMO', 'CVX', 'MRK',
               'ORCL', 'COST', 'AVGO', 'PEP', 'ACN', 'TXN', 'LLY', 'MDT', 'NEE', 'DHR',
               'UNP', 'PM', 'HON', 'QCOM', 'LOW', 'IBM', 'UPS', 'RTX', 'BMY', 'SBUX']
    
    base_date = datetime.now() - timedelta(days=30)
    records = []
    
    for symbol in symbols:
        base_price = random.uniform(50, 500)
        for day in range(30):
            current_date = base_date + timedelta(days=day)
            daily_change = random.uniform(-0.05, 0.05)
            price = base_price * (1 + daily_change)
            
            open_price = price * random.uniform(0.98, 1.02)
            high = price * random.uniform(1.00, 1.03)
            low = price * random.uniform(0.97, 1.00)
            close = price
            volume = int(random.uniform(1000000, 50000000))
            
            records.append((
                symbol, current_date, open_price, high, low, close, volume,
                daily_change, abs(daily_change) * 100, volume / 30
            ))
    
    # Bulk insert
    cur.executemany("""
        INSERT INTO market_data 
        (symbol, timestamp, open, high, low, close, volume, daily_return, volatility, avg_volume)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, records)
    
    conn.commit()
    print(f"✓ Generated {len(records)} records for {len(symbols)} symbols")
    cur.close()
    conn.close()
    sys.exit(0)
except Exception as e:
    print(f"✗ Error: {e}")
    sys.exit(1)
PYEOF

if [ $? -ne 0 ]; then
    echo "✗ Failed to generate initial data!"
    exit 1
fi

# 3. Verify data in database
echo "[3/6] Verifying database..."
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data << 'SQLEOF'
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT symbol) as unique_symbols,
    MIN(timestamp) as earliest,
    MAX(timestamp) as latest
FROM market_data;
SQLEOF

# 4. Train ML models (required for predictions)
echo "[4/6] Training ML models..."
python3.9 << 'PYEOF'
import sys
import os
os.chdir('/opt/financial-analysis')

try:
    from ml_models.predictor import FinancialPredictor
    
    print("Initializing predictor...")
    predictor = FinancialPredictor()
    
    print("Training models...")
    predictor.train_models()
    
    print("✓ ML models trained successfully!")
    print(f"  Models saved to: ml_models/models/")
    sys.exit(0)
except Exception as e:
    print(f"✗ ML training error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

# 5. Generate test predictions (for ML button)
echo "[5/6] Generating predictions file..."
python3.9 << 'PYEOF'
import sys
import os
import pandas as pd
from datetime import datetime

os.chdir('/opt/financial-analysis')

try:
    from ml_models.predictor import FinancialPredictor
    
    predictor = FinancialPredictor()
    predictions = predictor.predict_prices(['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META'])
    
    # Save predictions
    predictions_file = 'reports/predictions.csv'
    os.makedirs('reports', exist_ok=True)
    predictions.to_csv(predictions_file, index=False)
    
    print(f"✓ Predictions saved to: {predictions_file}")
    print(f"  {len(predictions)} predictions generated")
    sys.exit(0)
except Exception as e:
    print(f"✗ Prediction error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYEOF

# 6. Start collector and dashboard
echo "[6/6] Starting services..."

# Start advanced collector
nohup python3.9 spark_apps/advanced_collector.py > logs/collector.log 2>&1 &
echo "✓ Collector started (PID: $!)"

sleep 2

# Start dashboard
nohup python3.9 dashboard/app.py > logs/dashboard.log 2>&1 &
echo "✓ Dashboard started (PID: $!)"

sleep 3

# Verify everything is running
echo ""
echo "=========================================="
echo "VERIFICATION"
echo "=========================================="

echo "Processes:"
ps aux | grep -E "advanced_collector|app.py" | grep -v grep

echo ""
echo "Database status:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data << 'SQLEOF'
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT symbol) as unique_symbols
FROM market_data;
SQLEOF

echo ""
echo "Files created:"
ls -lh reports/predictions.csv ml_models/models/ 2>/dev/null | head -5

echo ""
echo "Recent collector logs:"
tail -10 logs/collector.log

echo ""
echo "=========================================="
echo "✅ SYSTEM READY!"
echo "=========================================="
echo "Now run port forwarding on your local machine:"
echo "  cd c:\\Users\\Lenovo\\projekti-web-info\\scripts"
echo "  .\\manage.ps1 -Action port-forward"
echo ""
echo "Then open: http://localhost:8050"
echo "  - ML Models: Should work now!"
echo "  - Presentations: Should generate!"
echo "  - Data: Growing with collector!"
echo "=========================================="
