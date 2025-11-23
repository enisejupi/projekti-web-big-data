#!/bin/bash
# Installation Script for Spark Master and Worker Nodes
# Te ekzekutohet ne te gjitha VM-te

# Don't exit on error - continue with installation
set +e

echo "===================================="
echo "Instalimi i Apache Spark Cluster"
echo "===================================="

# Update system
echo "Duke përditësuar sistemin..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Java 11
echo "Duke instaluar Java 11..."
sudo apt-get install -y openjdk-11-jdk

# Set JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64" >> ~/.bashrc

# Install Python 3.9 (available by default on Ubuntu 20.04)
echo "Duke instaluar Python 3.9..."
sudo apt-get install -y python3.9 python3.9-venv python3.9-dev
sudo apt-get install -y python3-pip

# Set Python 3.9 as default python3
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# Install system dependencies
echo "Duke instaluar varësitë e sistemit..."
sudo apt-get install -y build-essential libssl-dev libffi-dev python3-dev
sudo apt-get install -y wget curl git htop vim tmux

# Download Spark 3.5.0
if [ ! -d "/opt/spark" ]; then
    echo "Duke shkarkuar Apache Spark 3.5.0..."
    cd /opt
    sudo wget https://archive.apache.org/dist/spark/spark-3.5.0/spark-3.5.0-bin-hadoop3.tgz
    sudo tar -xzf spark-3.5.0-bin-hadoop3.tgz
    sudo mv spark-3.5.0-bin-hadoop3 spark
    sudo rm spark-3.5.0-bin-hadoop3.tgz
else
    echo "Spark eshte instaluar paraprakisht, duke kapercyer shkarkimin..."
fi

# Set Spark environment variables
echo "Duke konfiguruar variablat e mjedisit..."
export SPARK_HOME=/opt/spark
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
export PYSPARK_PYTHON=python3.9

echo "export SPARK_HOME=/opt/spark" >> ~/.bashrc
echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> ~/.bashrc
echo "export PYSPARK_PYTHON=python3.9" >> ~/.bashrc

# Create necessary directories
echo "Duke krijuar dosjet..."
sudo mkdir -p /opt/spark/logs
sudo mkdir -p /tmp/spark
sudo mkdir -p /opt/financial-analysis
sudo mkdir -p /opt/financial-analysis/data
sudo mkdir -p /opt/financial-analysis/models
sudo mkdir -p /opt/financial-analysis/exports
sudo mkdir -p /opt/financial-analysis/logs

# Set permissions
sudo chown -R krenuser:krenuser /opt/spark
sudo chown -R krenuser:krenuser /opt/financial-analysis
sudo chmod -R 755 /opt/spark
sudo chmod -R 755 /opt/financial-analysis

# Install Python packages
echo "Duke instaluar pakot Python..."
cd /opt/financial-analysis
python3.9 -m pip install --upgrade pip
python3.9 -m pip install -r requirements.txt

# Configure Spark
echo "Duke konfiguruar Spark..."
cp /opt/financial-analysis/configs/spark-defaults.conf /opt/spark/conf/spark-defaults.conf
cp /opt/financial-analysis/configs/workers /opt/spark/conf/workers

# Create spark-env.sh
cat > /opt/spark/conf/spark-env.sh << 'EOF'
#!/bin/bash

export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export SPARK_HOME=/opt/spark
export PYSPARK_PYTHON=python3.10

# Master configuration
export SPARK_MASTER_HOST=10.0.0.4
export SPARK_MASTER_PORT=7077
export SPARK_MASTER_WEBUI_PORT=9090

# Worker configuration
export SPARK_WORKER_CORES=16
export SPARK_WORKER_MEMORY=130g
export SPARK_WORKER_PORT=7078
export SPARK_WORKER_WEBUI_PORT=8081
export SPARK_WORKER_DIR=/opt/spark/work

# Performance tuning
export SPARK_DAEMON_MEMORY=10g
export SPARK_EXECUTOR_MEMORY=130g
export SPARK_DRIVER_MEMORY=120g
EOF

chmod +x /opt/spark/conf/spark-env.sh

# Install monitoring tools
echo "Duke instaluar mjetet e monitorimit..."
sudo apt-get install -y sysstat iotop nethogs

# Configure firewall (if UFW is enabled)
echo "Duke konfiguruar firewall..."
sudo ufw allow 7077/tcp  # Spark Master
sudo ufw allow 7078/tcp  # Spark Worker
sudo ufw allow 9090/tcp  # Spark Master UI
sudo ufw allow 8081/tcp  # Spark Worker UI
sudo ufw allow 8050/tcp  # Dashboard
sudo ufw allow 6066/tcp  # Spark REST server

# Optimize system for big data processing
echo "Duke optimizuar sistemin..."
sudo sysctl -w vm.swappiness=10
sudo sysctl -w net.core.somaxconn=4096
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=4096
sudo sysctl -w fs.file-max=2097152

# Make system optimizations persistent
cat << EOF | sudo tee -a /etc/sysctl.conf
vm.swappiness=10
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=4096
fs.file-max=2097152
EOF

# Set ulimit for the user
cat << EOF | sudo tee -a /etc/security/limits.conf
krenuser soft nofile 65536
krenuser hard nofile 65536
krenuser soft nproc 32768
krenuser hard nproc 32768
EOF

# Install PostgreSQL (only on Master node)
if [ "$(hostname)" = "VM1" ] || [ "$(hostname -I | grep -o '10\.0\.0\.4')" = "10.0.0.4" ]; then
    echo "===================================="
    echo "Installing PostgreSQL on Master..."
    echo "===================================="
    bash /opt/financial-analysis/scripts/install_postgres.sh
fi

echo "===================================="
echo "Instalimi u perfundua me sukses!"
echo "===================================="
echo ""
echo "Hapat e ardhshem:"
echo "1. Nese kjo eshte Master (VM1), ekzekutoni: start-master.sh"
echo "2. Nese kjo eshte Worker, ekzekutoni: start-worker.sh spark://10.0.0.4:7077"
echo ""
