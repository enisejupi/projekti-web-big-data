#!/bin/bash
# Complete system startup - Generate data, start collector, start dashboard

echo "=========================================="
echo "🚀 COMPLETE SYSTEM STARTUP"
echo "=========================================="

cd /opt/financial-analysis

# Step 1: Kill any old processes
echo ""
echo "[1/6] Stopping old processes..."
pkill -9 -f "collector"
pkill -9 -f "dashboard"
pkill -9 -f "app.py"
sleep 2

# Step 2: Generate initial test data
echo ""
echo "[2/6] Generating initial test data..."
python3.9 << 'PYEOF'
import psycopg2
import random
from datetime import datetime, timedelta

# Database connection
conn = psycopg2.connect(
    host="10.0.0.4",
    database="financial_data",
    user="financeuser",
    password="Finance@2025!Secure"
)
cur = conn.cursor()

# Generate data for 50 symbols
symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'TSLA', 'NVDA', 'JPM', 'V', 'WMT',
           'JNJ', 'PG', 'UNH', 'HD', 'BAC', 'MA', 'XOM', 'DIS', 'CSCO', 'PFE',
           'VZ', 'ADBE', 'NFLX', 'INTC', 'T', 'CRM', 'ABT', 'TMO', 'COST', 'NKE',
           'CVX', 'MCD', 'DHR', 'AVGO', 'ACN', 'TXN', 'NEE', 'LLY', 'PM', 'UPS',
           'BMY', 'ORCL', 'HON', 'QCOM', 'LOW', 'UNP', 'MDT', 'AMT', 'RTX', 'IBM']

base_date = datetime.now() - timedelta(days=30)
records_added = 0

for symbol in symbols:
    base_price = random.uniform(50, 500)
    for day in range(30):
        timestamp = base_date + timedelta(days=day)
        open_price = base_price * random.uniform(0.98, 1.02)
        high_price = open_price * random.uniform(1.00, 1.05)
        low_price = open_price * random.uniform(0.95, 1.00)
        close_price = random.uniform(low_price, high_price)
        volume = random.randint(1000000, 100000000)
        
        cur.execute("""
            INSERT INTO market_data (symbol, timestamp, open, high, low, close, volume, 
                                    daily_return, volatility, avg_volume, ma_5, ma_20)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (symbol, timestamp, open_price, high_price, low_price, close_price, volume,
              random.uniform(-0.05, 0.05), random.uniform(0.01, 0.05), 
              volume * random.uniform(0.9, 1.1), close_price * random.uniform(0.98, 1.02),
              close_price * random.uniform(0.95, 1.05)))
        records_added += 1

conn.commit()
print(f"✓ Generated {records_added} initial records for {len(symbols)} symbols")

# Check results
cur.execute("SELECT COUNT(*) as total, COUNT(DISTINCT symbol) as symbols FROM market_data")
result = cur.fetchone()
print(f"✓ Database now has: {result[0]} total records, {result[1]} unique symbols")

cur.close()
conn.close()
PYEOF

# Step 3: Start advanced collector (respects rate limits)
echo ""
echo "[3/6] Starting data collector..."
nohup python3.9 spark_apps/advanced_collector.py > logs/collector.log 2>&1 &
sleep 3

# Step 4: Start dashboard
echo ""
echo "[4/6] Starting dashboard..."
nohup python3.9 dashboard/app.py > logs/dashboard.log 2>&1 &
sleep 3

# Step 5: Verify processes
echo ""
echo "[5/6] Verifying processes..."
if ps aux | grep -v grep | grep "advanced_collector" > /dev/null; then
    echo "✓ Collector: RUNNING"
else
    echo "✗ Collector: FAILED"
fi

if ps aux | grep -v grep | grep "app.py" > /dev/null; then
    echo "✓ Dashboard: RUNNING"
else
    echo "✗ Dashboard: FAILED"
fi

# Step 6: Check database
echo ""
echo "[6/6] Database status..."
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "SELECT COUNT(*) as total, COUNT(DISTINCT symbol) as symbols, MAX(timestamp) as latest FROM market_data;"

# Show collector logs
echo ""
echo "=========================================="
echo "Recent collector logs:"
tail -10 logs/collector.log

echo ""
echo "=========================================="
echo "✅ STARTUP COMPLETE!"
echo "=========================================="
echo ""
echo "Next steps on your PC:"
echo "  1. Run: .\manage.ps1 -Action port-forward"
echo "  2. Open: http://localhost:8050"
echo "  3. Wait 2-3 minutes for Yahoo rate limit to clear"
echo ""
echo "=========================================="
