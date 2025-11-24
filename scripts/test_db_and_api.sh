#!/bin/bash
# Test database connection and check rate limits

cd /opt/financial-analysis

echo "=========================================="
echo "Testing Database Connection"
echo "=========================================="

python3.9 << 'PYEOF'
from utils.database import DatabaseManager
try:
    db = DatabaseManager()
    with db.get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM market_data")
            count = cur.fetchone()[0]
            print(f"✓ Database connected successfully!")
            print(f"  Current records: {count}")
except Exception as e:
    print(f"✗ Database connection failed: {e}")
    import traceback
    traceback.print_exc()
PYEOF

echo ""
echo "=========================================="
echo "Checking Yahoo Finance Rate Limit Status"
echo "=========================================="

# Wait a minute and try collecting a few symbols slowly
python3.9 << 'PYEOF'
import yfinance as yf
import time

test_symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'META']
success = 0
failed = 0

print("Testing data collection with delays...")
for symbol in test_symbols:
    try:
        ticker = yf.Ticker(symbol)
        data = ticker.history(period='1d')
        if not data.empty:
            print(f"✓ {symbol}: {len(data)} rows")
            success += 1
        else:
            print(f"⚠ {symbol}: empty data")
            failed += 1
    except Exception as e:
        print(f"✗ {symbol}: {str(e)[:50]}")
        failed += 1
    time.sleep(2)  # 2 second delay between requests

print(f"\nResults: {success} success, {failed} failed")
print(f"Success rate: {success*100/(success+failed):.1f}%")

if success == 0:
    print("\n⚠ WARNING: Yahoo Finance is blocking all requests!")
    print("This is a temporary rate limit. Need to:")
    print("1. Wait 15-30 minutes")
    print("2. Use slower collection rate")
    print("3. Or use alternative data source")
PYEOF

echo ""
echo "=========================================="
echo "Current Collector Status"
echo "=========================================="
ps aux | grep advanced_collector | grep -v grep
echo ""
echo "Last 15 log lines:"
tail -15 logs/collector.log

echo ""
echo "=========================================="
