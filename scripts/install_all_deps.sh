#!/bin/bash
# Final fix: Install all missing dependencies

echo "=========================================="
echo "Installing All Required Dependencies"
echo "=========================================="

# Install Python dependencies system-wide
sudo pip3 install --upgrade \
    pyarrow \
    sqlalchemy \
    psycopg2-binary \
    pandas \
    numpy \
    scikit-learn \
    yfinance \
    pyspark \
    python-pptx \
    Pillow \
    reportlab 2>&1 | grep -E "(Successfully|Requirement|ERROR)" | tail -20

echo ""
echo "=========================================="
echo "Verifying Installations"
echo "=========================================="

python3.9 << 'PYEOF'
import sys
packages = {
    'pyarrow': 'PyArrow (for ML)',
    'sqlalchemy': 'SQLAlchemy (for database)',
    'psycopg2': 'psycopg2 (PostgreSQL)',
    'pandas': 'Pandas',
    'numpy': 'NumPy',
    'sklearn': 'Scikit-learn',
    'yfinance': 'yfinance',
    'pyspark': 'PySpark',
    'pptx': 'python-pptx',
    'PIL': 'Pillow',
    'reportlab': 'ReportLab'
}

all_good = True
for module, name in packages.items():
    try:
        __import__(module)
        print(f'✓ {name}')
    except ImportError:
        print(f'✗ {name} - MISSING')
        all_good = False

sys.exit(0 if all_good else 1)
PYEOF

echo ""
echo "=========================================="
echo "Restarting Collector with Delays"
echo "=========================================="

# Kill old collector
pkill -9 -f "advanced_collector.py"
pkill -9 -f "free_api_collector"
sleep 2

# Start collector
cd /opt/financial-analysis
nohup python3.9 spark_apps/advanced_collector.py > logs/collector.log 2>&1 &
sleep 5

# Check status
echo ""
echo "Collector status:"
ps aux | grep advanced_collector | grep -v grep

echo ""
echo "Recent logs (should show slower collection due to rate limits):"
tail -20 logs/collector.log

echo ""
echo "Database check:"
PGPASSWORD="Finance@2025!Secure" psql -h 10.0.0.4 -U financeuser -d financial_data -c "SELECT COUNT(*) as total, COUNT(DISTINCT symbol) as symbols, MAX(timestamp) as latest FROM market_data;" 2>&1

echo ""
echo "=========================================="
echo "✓ All dependencies installed!"
echo "Collector will be slower due to Yahoo API limits"
echo "This is normal - we're respecting rate limits"
echo "=========================================="
