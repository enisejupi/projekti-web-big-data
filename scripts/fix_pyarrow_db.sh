#!/bin/bash
# Fix pyarrow and database issues

echo "=========================================="
echo "Part 1: Install pyarrow from binary"
echo "=========================================="

# Install pyarrow from pre-built wheel
sudo pip3 install --upgrade pip
sudo pip3 install pyarrow --no-build-isolation 2>&1 | tail -10

# If that fails, use conda-forge binary
if ! python3.9 -c "import pyarrow" 2>/dev/null; then
    echo "Trying alternative installation..."
    sudo pip3 install --force-reinstall --no-cache-dir pyarrow==14.0.1 2>&1 | tail -10
fi

echo ""
echo "=========================================="
echo "Part 2: Check Database Connection"
echo "=========================================="

# Test database connection
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "\dt" 2>&1

echo ""
echo "Check table structure:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "\d market_data" 2>&1

echo ""
echo "Recent records:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "SELECT COUNT(*), MAX(timestamp) FROM market_data;" 2>&1

echo ""
echo "Check if collector can connect:"
cd /opt/financial-analysis
python3.9 -c "
from utils.database import DatabaseManager
import sys
try:
    db = DatabaseManager()
    with db.get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute('SELECT COUNT(*) FROM market_data')
            count = cur.fetchone()[0]
            print(f'✓ Database connected! Total records: {count}')
            sys.exit(0)
except Exception as e:
    print(f'✗ Database error: {e}')
    sys.exit(1)
"

echo ""
echo "=========================================="
echo "Part 3: Check Collector Logs"
echo "=========================================="
tail -30 /opt/financial-analysis/logs/collector.log

echo ""
echo "=========================================="
