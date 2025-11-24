#!/bin/bash
# Quick test script to verify everything is accessible

echo "=========================================="
echo "Testing Financial Analysis Setup"
echo "=========================================="
echo ""

# Test 1: Python and packages
echo "Test 1: Python Environment"
python3.9 --version
echo ""

# Test 2: Spark
echo "Test 2: Spark Installation"
if [ -d "/opt/spark" ]; then
    echo "✓ Spark found at /opt/spark"
    /opt/spark/bin/spark-submit --version 2>&1 | head -5
else
    echo "✗ Spark not found"
fi
echo ""

# Test 3: Database
echo "Test 3: Database"
if [ -f "/opt/financial-analysis/data/market_data.db" ]; then
    echo "✓ Database exists"
    DB_SIZE=$(du -h /opt/financial-analysis/data/market_data.db | cut -f1)
    echo "  Size: $DB_SIZE"
    
    # Count records
    RECORD_COUNT=$(sqlite3 /opt/financial-analysis/data/market_data.db "SELECT COUNT(*) FROM market_data;" 2>/dev/null)
    if [ ! -z "$RECORD_COUNT" ]; then
        echo "  Records: $RECORD_COUNT"
    fi
else
    echo "⚠ Database not found (will be created by collector)"
fi
echo ""

# Test 4: Check ports
echo "Test 4: Port Availability"
netstat -tuln | grep -E ':(8050|7077|8080|4040)' || echo "No services listening on expected ports"
echo ""

# Test 5: Data directory
echo "Test 5: Data Directory"
if [ -d "/opt/financial-analysis/data/raw" ]; then
    PARQUET_COUNT=$(find /opt/financial-analysis/data/raw -name "*.parquet" 2>/dev/null | wc -l)
    echo "✓ Data directory exists"
    echo "  Parquet files: $PARQUET_COUNT"
else
    echo "⚠ Data directory not found"
fi
echo ""

# Test 6: ML Models
echo "Test 6: ML Models"
if [ -d "/opt/financial-analysis/models" ]; then
    echo "✓ Models directory exists"
    find /opt/financial-analysis/models -type d -name "*forest*" -o -name "*boost*" -o -name "*lstm*" 2>/dev/null
else
    echo "⚠ Models directory not found"
fi
echo ""

# Test 7: Check Python packages
echo "Test 7: Python Packages"
python3.9 -c "import pyspark; print('✓ pyspark:', pyspark.__version__)" 2>/dev/null || echo "✗ pyspark not found"
python3.9 -c "import dash; print('✓ dash:', dash.__version__)" 2>/dev/null || echo "✗ dash not found"
python3.9 -c "import sklearn; print('✓ scikit-learn:', sklearn.__version__)" 2>/dev/null || echo "✗ scikit-learn not found"
python3.9 -c "import tensorflow; print('✓ tensorflow:', tensorflow.__version__)" 2>/dev/null || echo "✗ tensorflow not found"
echo ""

echo "=========================================="
echo "Test Complete"
echo "=========================================="
