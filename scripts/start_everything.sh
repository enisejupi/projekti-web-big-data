#!/bin/bash
# Complete system startup and verification

echo "=========================================="
echo "Complete System Startup"
echo "=========================================="

cd /opt/financial-analysis

# 1. Kill all old processes
echo "[1/6] Stopping old processes..."
pkill -9 -f "advanced_collector"
pkill -9 -f "free_api_collector"
pkill -9 -f "data_collector"
pkill -9 -f "dashboard"
pkill -9 -f "app.py"
sleep 3

# 2. Check database
echo "[2/6] Checking database..."
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data << 'EOSQL'
SELECT 
    COUNT(*) as total_records, 
    COUNT(DISTINCT symbol) as unique_symbols,
    MAX(timestamp) as latest_data
FROM market_data;
EOSQL

# 3. Start collector with rate limiting
echo "[3/6] Starting collector with rate limits..."
cat > /tmp/start_collector.py << 'PYEOF'
#!/usr/bin/env python3.9
import subprocess
import sys
import os

os.chdir('/opt/financial-analysis')

# Start collector
proc = subprocess.Popen([
    'python3.9', 
    'spark_apps/simple_data_generator.py'  # Use simple generator first
], stdout=open('logs/collector.log', 'w'), stderr=subprocess.STDOUT)

print(f"Started collector with PID: {proc.pid}")
PYEOF

python3.9 /tmp/start_collector.py
sleep 5

# 4. Verify collector started
echo "[4/6] Verifying collector..."
ps aux | grep -E "simple_data_generator|advanced_collector" | grep -v grep

# 5. Start dashboard
echo "[5/6] Starting dashboard..."
cd /opt/financial-analysis/dashboard
nohup python3.9 app.py > ../logs/dashboard.log 2>&1 &
sleep 3

# 6. Verify everything
echo "[6/6] Final verification..."
echo ""
echo "Running processes:"
ps aux | grep -E "python3.9.*collector|python3.9.*app.py" | grep -v grep
echo ""
echo "Recent collector logs:"
tail -15 /opt/financial-analysis/logs/collector.log
echo ""
echo "Recent dashboard logs:"
tail -10 /opt/financial-analysis/logs/dashboard.log
echo ""
echo "Database status:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "SELECT COUNT(*) as records FROM market_data;"

echo ""
echo "=========================================="
echo "Startup complete!"
echo "Wait 2-3 minutes for data collection"
echo "Then run port forwarding"
echo "=========================================="
