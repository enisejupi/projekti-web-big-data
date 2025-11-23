#!/bin/bash
# Skript për të vendosur të drejtat e ekzekutimit për të gjitha skriptet
# Ekzekutohet automatikisht pas deployment

echo "Duke vendosur të drejtat e ekzekutimit..."

# Scripts directory
chmod +x /opt/financial-analysis/scripts/*.sh

# Python scripts
chmod +x /opt/financial-analysis/spark_apps/*.py
chmod +x /opt/financial-analysis/ml_models/*.py
chmod +x /opt/financial-analysis/dashboard/*.py

# Make sure directories are writable
chmod -R 755 /opt/financial-analysis/data
chmod -R 755 /opt/financial-analysis/models
chmod -R 755 /opt/financial-analysis/exports
chmod -R 755 /opt/financial-analysis/logs

echo "✓ Të drejtat u vendosën me sukses"
