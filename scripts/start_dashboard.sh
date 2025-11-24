#!/bin/bash
# Start dashboard properly

cd /opt/financial-analysis/dashboard

echo "Stopping old dashboard..."
pkill -9 -f "python3.9 app.py"
sleep 2

echo "Starting dashboard on port 8050..."
nohup python3.9 app.py > ../logs/dashboard.log 2>&1 &
sleep 5

echo "Checking dashboard..."
if ps aux | grep "python3.9 app.py" | grep -v grep > /dev/null; then
    echo "✓ Dashboard is running!"
    ps aux | grep "python3.9 app.py" | grep -v grep
else
    echo "✗ Dashboard failed to start"
    echo "Logs:"
    tail -20 ../logs/dashboard.log
    exit 1
fi

echo ""
echo "Recent logs:"
tail -15 ../logs/dashboard.log

echo ""
echo "✓ Dashboard ready on port 8050"
echo "Run: .\manage.ps1 -Action port-forward"
