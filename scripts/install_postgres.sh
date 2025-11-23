#!/bin/bash
# Script per te instaluar dhe konfiguruar PostgreSQL ne VM Master

echo "======================================"
echo "PostgreSQL Installation dhe Setup"
echo "======================================"
echo ""

# Install PostgreSQL
echo "Duke instaluar PostgreSQL..."
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# Start PostgreSQL service
echo "Duke nisur PostgreSQL service..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
echo "Duke krijuar database dhe user..."
sudo -u postgres psql << EOF
CREATE DATABASE financial_data;
CREATE USER financeuser WITH ENCRYPTED PASSWORD 'Finance@2025!Secure';
GRANT ALL PRIVILEGES ON DATABASE financial_data TO financeuser;
ALTER DATABASE financial_data OWNER TO financeuser;
EOF

# Configure PostgreSQL to accept remote connections
echo "Duke konfiguruar PostgreSQL per lidhje te largeta..."
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/*/main/postgresql.conf

# Allow connections from all IPs in pg_hba.conf
echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a /etc/postgresql/*/main/pg_hba.conf

# Restart PostgreSQL
echo "Duke ri-nisur PostgreSQL..."
sudo systemctl restart postgresql

# Create tables
echo "Duke krijuar tabelat..."
sudo -u postgres psql -d financial_data -U financeuser << EOF
-- Market Data Table
CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    open DECIMAL(20, 6),
    high DECIMAL(20, 6),
    low DECIMAL(20, 6),
    close DECIMAL(20, 6),
    volume BIGINT,
    adj_close DECIMAL(20, 6),
    -- Technical Indicators
    sma_20 DECIMAL(20, 6),
    sma_50 DECIMAL(20, 6),
    ema_12 DECIMAL(20, 6),
    ema_26 DECIMAL(20, 6),
    rsi DECIMAL(10, 4),
    macd DECIMAL(20, 6),
    macd_signal DECIMAL(20, 6),
    bb_upper DECIMAL(20, 6),
    bb_middle DECIMAL(20, 6),
    bb_lower DECIMAL(20, 6),
    atr DECIMAL(20, 6),
    obv BIGINT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(symbol, timestamp)
);

CREATE INDEX idx_market_data_symbol ON market_data(symbol);
CREATE INDEX idx_market_data_timestamp ON market_data(timestamp);
CREATE INDEX idx_market_data_symbol_timestamp ON market_data(symbol, timestamp);

-- ML Predictions Table
CREATE TABLE IF NOT EXISTS ml_predictions (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    prediction_date TIMESTAMP NOT NULL,
    predicted_price DECIMAL(20, 6),
    model_name VARCHAR(50),
    confidence_score DECIMAL(5, 4),
    actual_price DECIMAL(20, 6),
    error DECIMAL(20, 6),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_predictions_symbol ON ml_predictions(symbol);
CREATE INDEX idx_predictions_timestamp ON ml_predictions(timestamp);

-- Investment Recommendations Table
CREATE TABLE IF NOT EXISTS investment_recommendations (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    recommendation VARCHAR(20) NOT NULL,
    invest_score DECIMAL(5, 2),
    target_price DECIMAL(20, 6),
    stop_loss DECIMAL(20, 6),
    reasoning TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_recommendations_symbol ON investment_recommendations(symbol);
CREATE INDEX idx_recommendations_timestamp ON investment_recommendations(timestamp);

-- Cluster Analysis Table
CREATE TABLE IF NOT EXISTS cluster_analysis (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(20) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    cluster_id INTEGER,
    cluster_label VARCHAR(50),
    distance_to_center DECIMAL(20, 6),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cluster_symbol ON cluster_analysis(symbol);
CREATE INDEX idx_cluster_id ON cluster_analysis(cluster_id);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO financeuser;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO financeuser;

EOF

# Allow port through firewall
echo "Duke konfiguruar firewall..."
sudo ufw allow 5432/tcp

echo ""
echo "======================================"
echo "PostgreSQL u instalua me sukses!"
echo "======================================"
echo ""
echo "Database: financial_data"
echo "User: financeuser"
echo "Port: 5432"
echo "Host: 10.0.0.4"
echo ""
echo "Test connection:"
echo "psql -h 10.0.0.4 -U financeuser -d financial_data"
echo ""
