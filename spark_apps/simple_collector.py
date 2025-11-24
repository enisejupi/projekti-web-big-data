#!/usr/bin/env python3.9
"""
Simple Data Collector - Writes to SQLite database
Ultra-simple, no authentication issues
"""

import yfinance as yf
import sqlite3
from datetime import datetime, timedelta
import time
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Asset list (363 total)
ASSETS = [
    # US Stocks (100)
    'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK-B', 'UNH', 'JNJ',
    'V', 'PG', 'JPM', 'MA', 'HD', 'CVX', 'MRK', 'ABBV', 'PEP', 'KO',
    'AVGO', 'COST', 'PFE', 'TMO', 'MCD', 'CSCO', 'ABT', 'ACN', 'DHR', 'LIN',
    'ADBE', 'NKE', 'WMT', 'NEE', 'CRM', 'TXN', 'BMY', 'CMCSA', 'PM', 'HON',
    'QCOM', 'RTX', 'UPS', 'IBM', 'AMGN', 'SBUX', 'BA', 'CAT', 'GE', 'AMD',
    'INTC', 'INTU', 'AMAT', 'T', 'LOW', 'GS', 'BLK', 'NOW', 'DE', 'SPGI',
    'LMT', 'MDLZ', 'AXP', 'SYK', 'BKNG', 'GILD', 'ADP', 'MMC', 'TJX', 'C',
    'CVS', 'PLD', 'ISRG', 'ZTS', 'CB', 'MMM', 'CI', 'ADI', 'SO', 'MO',
    'DUK', 'BDX', 'SHW', 'CL', 'EOG', 'ITW', 'ICE', 'USB', 'NOC', 'PNC',
    'REGN', 'APD', 'CME', 'GD', 'EMR', 'TGT', 'HUM', 'NSC', 'COF', 'BSX',
    # European stocks (50)
    'MC.PA', 'ASML.AS', 'OR.PA', 'SAP.DE', 'RMS.PA', 'SIE.DE', 'NOVO-B.CO',
    'AZN.L', 'AI.PA', 'SAN.PA', 'TTE.PA', 'ALV.DE', 'AIR.PA', 'BN.PA',
    'SHEL.L', 'SU.PA', 'BBVA.MC', 'IBE.MC', 'BNP.PA', 'DTE.DE', 'VOW3.DE',
    'ENEL.MI', 'ITX.MC', 'ABI.BR', 'ADYEN.AS', 'DG.PA', 'EN.PA', 'CS.PA',
    'SGO.PA', 'VIV.PA', 'MT.AS', 'GLEN.L', 'BP.L', 'HSBA.L', 'ULVR.L',
    'GSK.L', 'DGE.L', 'NG.L', 'BARC.L', 'LLOY.L', 'VOD.L', 'PRU.L',
    'RIO.L', 'BHP.L', 'AAL.L', 'BATS.L', 'RKT.L', 'REL.L', 'AV.L', 'BA.L'
]

def get_db_connection():
    conn = sqlite3.connect('/opt/financial-analysis/data/market_data.db')
    # Create table if not exists
    conn.execute('''
        CREATE TABLE IF NOT EXISTS market_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            symbol TEXT,
            timestamp TEXT,
            open REAL,
            high REAL,
            low REAL,
            close REAL,
            volume INTEGER,
            daily_return REAL,
            volatility REAL,
            avg_volume REAL,
            ma_5 REAL,
            ma_20 REAL
        )
    ''')
    conn.commit()
    return conn

def collect_batch(symbols):
    """Collect data for a batch of symbols"""
    records = 0
    conn = get_db_connection()
    cur = conn.cursor()
    
    for symbol in symbols:
        try:
            ticker = yf.Ticker(symbol)
            hist = ticker.history(period="1mo")
            
            if hist.empty:
                continue
            
            latest = hist.iloc[-1]
            timestamp = datetime.now().isoformat()
            
            # Calculate metrics
            daily_return = ((latest['Close'] - hist.iloc[-2]['Close']) / hist.iloc[-2]['Close'] * 100) if len(hist) > 1 else 0
            volatility = hist['Close'].pct_change().std() * 100
            avg_volume = hist['Volume'].mean()
            ma_5 = hist['Close'].tail(5).mean()
            ma_20 = hist['Close'].tail(20).mean()
            
            # Insert into database
            cur.execute("""
                INSERT INTO market_data 
                (symbol, timestamp, open, high, low, close, volume, daily_return, volatility, avg_volume, ma_5, ma_20)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (symbol, timestamp, float(latest['Open']), float(latest['High']), float(latest['Low']),
                  float(latest['Close']), int(latest['Volume']), float(daily_return), 
                  float(volatility), float(avg_volume), float(ma_5), float(ma_20)))
            
            records += 1
            
        except Exception as e:
            logger.error(f"Error processing {symbol}: {e}")
            continue
    
    conn.commit()
    cur.close()
    conn.close()
    
    return records

def main():
    logger.info("="*60)
    logger.info("Starting Simple Data Collector - 84 hours (3.5 days)")
    logger.info(f"Total assets: {len(ASSETS)}")
    logger.info("="*60)
    
    end_time = datetime.now() + timedelta(hours=84)
    iteration = 0
    batch_size = 20
    
    while datetime.now() < end_time:
        iteration += 1
        start = datetime.now()
        
        logger.info(f"\nIteration #{iteration} - {start.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"Remaining: {(end_time - start).total_seconds() / 3600:.1f} hours")
        
        total_records = 0
        for i in range(0, len(ASSETS), batch_size):
            batch = ASSETS[i:i+batch_size]
            records = collect_batch(batch)
            total_records += records
            logger.info(f"  Batch {i//batch_size + 1}: {records} records saved")
            time.sleep(2)
        
        elapsed = (datetime.now() - start).total_seconds()
        logger.info(f"Iteration complete: {total_records} records in {elapsed:.1f}s")
        
        # Wait 5 minutes between iterations
        wait_time = max(0, 300 - elapsed)
        if wait_time > 0:
            logger.info(f"Waiting {wait_time/60:.1f} minutes...")
            time.sleep(wait_time)
    
    logger.info("\nData collection completed successfully!")

if __name__ == "__main__":
    main()
