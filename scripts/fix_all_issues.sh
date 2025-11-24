#!/bin/bash
# Comprehensive fix for all issues

echo "=========================================="
echo "Fixing All Issues"
echo "=========================================="

cd /opt/financial-analysis

# 1. Install pyarrow system-wide (for ML models)
echo "[1/6] Installing pyarrow for ML models..."
sudo pip3 install pyarrow pandas numpy scikit-learn 2>&1 | tail -5

# 2. Install presentation dependencies
echo "[2/6] Installing presentation dependencies..."
sudo pip3 install python-pptx Pillow reportlab 2>&1 | tail -5

# 3. Verify installations
echo "[3/6] Verifying installations..."
python3.9 -c "import pyarrow; print('✓ pyarrow:', pyarrow.__version__)" 2>&1
python3.9 -c "import pptx; print('✓ python-pptx:', pptx.__version__)" 2>&1
python3.9 -c "import PIL; print('✓ Pillow:', PIL.__version__)" 2>&1

# 4. Kill any old collectors
echo "[4/6] Stopping old collectors..."
pkill -9 -f "advanced_collector.py"
pkill -9 -f "free_api_collector"
pkill -9 -f "data_collector.py"
sleep 2

# 5. Start advanced collector
echo "[5/6] Starting advanced collector..."
cd /opt/financial-analysis
nohup python3.9 spark_apps/advanced_collector.py > logs/collector.log 2>&1 &
sleep 3

# 6. Verify everything
echo "[6/6] Verifying status..."
echo ""
echo "Collector process:"
ps aux | grep advanced_collector | grep -v grep
echo ""
echo "Recent logs:"
tail -10 logs/collector.log
echo ""
echo "Database records:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "SELECT COUNT(*) as total, COUNT(DISTINCT symbol) as symbols, MAX(timestamp) as latest FROM market_data;" 2>&1

echo ""
echo "=========================================="
echo "✓ All fixes applied!"
echo "=========================================="
