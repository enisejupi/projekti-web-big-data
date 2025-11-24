#!/bin/bash
# Generate initial data quickly without rate limits

cd /opt/financial-analysis

echo "=========================================="
echo "Generating Initial Test Data"
echo "=========================================="

# Create a simple data generator that doesn't use Yahoo Finance
python3.9 << 'PYEOF'
import psycopg2
import random
from datetime import datetime, timedelta

# Database connection
conn = psycopg2.connect(
    host="10.0.0.4",
    port=5432,
    database="financial_data",
    user="financeuser",
    password="Finance@2025!Secure"
)
cur = conn.cursor()

# Generate test data for popular symbols
symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META', 'TSLA', 'NVDA', 'JPM', 'V', 'WMT',
           'JNJ', 'PG', 'UNH', 'HD', 'MA', 'BAC', 'XOM', 'DIS', 'CSCO', 'ADBE']

print(f"Generating test data for {len(symbols)} symbols...")

base_prices = {
    'AAPL': 190, 'MSFT': 380, 'GOOGL': 140, 'AMZN': 150, 'META': 350,
    'TSLA': 240, 'NVDA': 480, 'JPM': 170, 'V': 260, 'WMT': 160,
    'JNJ': 160, 'PG': 150, 'UNH': 520, 'HD': 360, 'MA': 450,
    'BAC': 35, 'XOM': 110, 'DIS': 95, 'CSCO': 52, 'ADBE': 580
}

records_generated = 0
now = datetime.now()

for symbol in symbols:
    base_price = base_prices.get(symbol, 100)
    
    # Generate 30 days of data
    for days_ago in range(30, 0, -1):
        timestamp = now - timedelta(days=days_ago)
        
        # Simulate price movements
        open_price = base_price * (1 + random.uniform(-0.02, 0.02))
        high = open_price * (1 + random.uniform(0, 0.03))
        low = open_price * (1 - random.uniform(0, 0.03))
        close_price = (high + low) / 2 * (1 + random.uniform(-0.01, 0.01))
        volume = random.randint(50000000, 150000000)
        
        daily_return = (close_price - open_price) / open_price
        volatility = random.uniform(0.01, 0.05)
        avg_volume = volume * random.uniform(0.9, 1.1)
        ma_5 = close_price * random.uniform(0.98, 1.02)
        ma_20 = close_price * random.uniform(0.96, 1.04)
        
        cur.execute("""
            INSERT INTO market_data 
            (symbol, timestamp, open, high, low, close, volume, 
             daily_return, volatility, avg_volume, ma_5, ma_20)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (symbol, timestamp, open_price, high, low, close_price, volume,
              daily_return, volatility, avg_volume, ma_5, ma_20))
        
        records_generated += 1
        
        if records_generated % 100 == 0:
            conn.commit()
            print(f"  Generated {records_generated} records...")

conn.commit()
print(f"\n✓ Successfully generated {records_generated} records!")
print(f"  Symbols: {len(symbols)}")
print(f"  Days per symbol: 30")

# Verify
cur.execute("SELECT COUNT(*), COUNT(DISTINCT symbol) FROM market_data")
total, symbols_count = cur.fetchone()
print(f"\nDatabase verification:")
print(f"  Total records: {total}")
print(f"  Unique symbols: {symbols_count}")

cur.close()
conn.close()
PYEOF

echo ""
echo "=========================================="
echo "Verification"
echo "=========================================="

PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data << 'EOSQL'
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT symbol) as unique_symbols,
    MIN(timestamp)::date as earliest,
    MAX(timestamp)::date as latest
FROM market_data;
EOSQL

echo ""
echo "=========================================="
echo "✓ Test data generated!"
echo "Now you can:"
echo "1. Run port forwarding"
echo "2. Access dashboard"
echo "3. Run ML models"
echo "4. Generate presentations"
echo "=========================================="
