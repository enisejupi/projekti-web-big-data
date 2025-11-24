#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
Advanced Financial Data Collector - Maximum Performance
Collects 500+ assets using ALL available VM resources
"""

import yfinance as yf
from datetime import datetime, timedelta
import time
import logging
import sqlite3
from concurrent.futures import ThreadPoolExecutor, as_completed
import multiprocessing

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Database path
DB_PATH = '/opt/financial-analysis/data/market_data.db'

# EXPANDED ASSET LIST - 500+ symbols using full VM capacity
SYMBOLS = [
    # US Large Cap (100 symbols)
    'AAPL', 'MSFT', 'GOOGL', 'GOOG', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK-B', 'UNH',
    'JNJ', 'XOM', 'JPM', 'V', 'PG', 'MA', 'HD', 'CVX', 'MRK', 'ABBV',
    'PEP', 'AVGO', 'COST', 'KO', 'ADBE', 'TMO', 'WMT', 'MCD', 'CSCO', 'ACN',
    'ABT', 'NKE', 'LIN', 'NFLX', 'CRM', 'DIS', 'VZ', 'CMCSA', 'DHR', 'TXN',
    'INTC', 'NEE', 'PM', 'RTX', 'ORCL', 'AMD', 'UNP', 'WFC', 'HON', 'QCOM',
    'MS', 'LOW', 'AMGN', 'BA', 'COP', 'IBM', 'BMY', 'SPGI', 'GE', 'CAT',
    'SBUX', 'GILD', 'LMT', 'NOW', 'DE', 'AXP', 'BKNG', 'BLK', 'ISRG', 'ADI',
    'MDLZ', 'PLD', 'SCHW', 'CB', 'AMT', 'TJX', 'CVS', 'ADP', 'SYK', 'AMAT',
    'VRTX', 'REGN', 'CI', 'MMC', 'PGR', 'ZTS', 'MU', 'DUK', 'CME', 'SO',
    'TMUS', 'BDX', 'EOG', 'NOC', 'ITW', 'CCI', 'LRCX', 'HUM', 'USB', 'PNC',
    
    # US Mid Cap (100 symbols)
    'PANW', 'KLAC', 'APH', 'MCO', 'SNPS', 'CDNS', 'MCHP', 'NXPI', 'MAR', 'MSI',
    'ORLY', 'AJG', 'WM', 'GPN', 'SHW', 'CSX', 'TT', 'ADSK', 'AZO', 'AFL',
    'NSC', 'APO', 'CARR', 'HCA', 'ROP', 'PSA', 'TDG', 'WELL', 'ICE', 'JCI',
    'PAYX', 'MSCI', 'TRV', 'AIG', 'GM', 'FIS', 'AMP', 'ALL', 'FTNT', 'DHI',
    'FICO', 'HSY', 'PCAR', 'SRE', 'PCG', 'KMI', 'O', 'SPG', 'TEL', 'GIS',
    'CPRT', 'RSG', 'DLR', 'EXC', 'MNST', 'FAST', 'ODFL', 'VRSK', 'KMB', 'ROK',
    'EA', 'IQV', 'TROW', 'CTAS', 'IDXX', 'XEL', 'CMG', 'DXCM', 'PRU', 'WMB',
    'BKR', 'CTVA', 'GWW', 'EW', 'IT', 'FITB', 'AWK', 'VICI', 'VMC', 'MLM',
    'ACGL', 'ED', 'GLW', 'DOV', 'BIIB', 'PH', 'RMD', 'DFS', 'ANSS', 'CTSH',
    'WEC', 'MTB', 'PWR', 'KEYS', 'FTV', 'SBAC', 'CDW', 'WAB', 'HBAN', 'RF',
    
    # Technology & Software (50 symbols)
    'CRM', 'SNOW', 'PLTR', 'DDOG', 'NET', 'TEAM', 'WDAY', 'ZM', 'ZS', 'OKTA',
    'CRWD', 'MDB', 'TWLO', 'SPLK', 'DOCU', 'DKNG', 'RBLX', 'U', 'PATH', 'BILL',
    'CFLT', 'S', 'DBX', 'BOX', 'RNG', 'DOCN', 'FROG', 'GTLB', 'ESTC', 'DT',
    'PCOR', 'APPN', 'NCNO', 'TENB', 'BL', 'ASAN', 'AI', 'MSFT', 'ORCL', 'SAP',
    'INTU', 'ANSS', 'CDNS', 'SNPS', 'ADSK', 'FTNT', 'PANW', 'ZS', 'CRWD', 'NET',
    
    # Financial Services (50 symbols)
    'JPM', 'BAC', 'WFC', 'C', 'GS', 'MS', 'BLK', 'SCHW', 'CB', 'AXP',
    'USB', 'PNC', 'TFC', 'COF', 'BK', 'STT', 'AFL', 'AIG', 'PRU', 'MET',
    'ALL', 'TRV', 'PGR', 'AJG', 'MMC', 'AON', 'WTW', 'BRO', 'HIG', 'CMA',
    'FITB', 'KEY', 'HBAN', 'RF', 'CFG', 'MTB', 'SIVB', 'ZION', 'WTFC', 'FHN',
    'SNV', 'EWBC', 'PBCT', 'WAL', 'CMA', 'NTRS', 'BBT', 'STI', 'CBSH', 'FNB',
    
    # Healthcare & Biotech (50 symbols)
    'UNH', 'JNJ', 'PFE', 'ABBV', 'TMO', 'ABT', 'DHR', 'MRK', 'LLY', 'BMY',
    'AMGN', 'GILD', 'CVS', 'CI', 'HUM', 'ISRG', 'VRTX', 'REGN', 'ZTS', 'IDXX',
    'SYK', 'BDX', 'EW', 'BSX', 'MDT', 'IQV', 'RMD', 'DXCM', 'ALGN', 'HOLX',
    'BAX', 'ELV', 'COO', 'TECH', 'CNC', 'HCA', 'DVA', 'UHS', 'THC', 'MOH',
    'BIIB', 'MRNA', 'BNTX', 'NVAX', 'SGEN', 'ALNY', 'BMRN', 'UTHR', 'EXAS', 'INCY',
    
    # Energy & Materials (50 symbols)
    'XOM', 'CVX', 'COP', 'SLB', 'EOG', 'MPC', 'PSX', 'VLO', 'OXY', 'HES',
    'KMI', 'WMB', 'BKR', 'HAL', 'DVN', 'FANG', 'MRO', 'APA', 'CTRA', 'OVV',
    'LIN', 'APD', 'ECL', 'SHW', 'NEM', 'FCX', 'GOLD', 'NUE', 'STLD', 'CLF',
    'VMC', 'MLM', 'DD', 'DOW', 'LYB', 'CF', 'MOS', 'FMC', 'ALB', 'CE',
    'PPG', 'EMN', 'IFF', 'FUL', 'AXTA', 'RPM', 'SEE', 'AVY', 'BALL', 'PKG',
    
    # Consumer & Retail (50 symbols)
    'AMZN', 'TSLA', 'HD', 'WMT', 'MCD', 'NKE', 'SBUX', 'TJX', 'LOW', 'TGT',
    'BKNG', 'MAR', 'CMG', 'YUM', 'DPZ', 'QSR', 'ROST', 'ULTA', 'DG', 'DLTR',
    'KSS', 'M', 'JWN', 'GPS', 'ANF', 'AEO', 'URBN', 'BBY', 'GME', 'BBBY',
    'WSM', 'RH', 'TSCO', 'ORLY', 'AZO', 'AAP', 'GPC', 'POOL', 'LEG', 'TPX',
    'MHK', 'WHR', 'LEN', 'DHI', 'PHM', 'NVR', 'KBH', 'TOL', 'MTH', 'BZH',
    
    # Industrial & Transportation (50 symbols)
    'BA', 'UNP', 'CAT', 'HON', 'RTX', 'LMT', 'DE', 'GE', 'MMM', 'ITW',
    'CSX', 'NSC', 'UPS', 'FDX', 'ODFL', 'JBHT', 'CHRW', 'XPO', 'KNX', 'EXPD',
    'EMR', 'ETN', 'PH', 'ROK', 'DOV', 'FTV', 'IR', 'CARR', 'OTIS', 'PWR',
    'AME', 'ROP', 'TT', 'CMI', 'PCAR', 'WAB', 'ALK', 'DAL', 'UAL', 'AAL',
    'LUV', 'JBLU', 'SAVE', 'HA', 'R', 'SKYW', 'MESA', 'ALGT', 'ATSG', 'AAWW',
]

def get_db_connection():
    """Create database connection and ensure table exists"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS market_data (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            symbol TEXT NOT NULL,
            price REAL,
            volume INTEGER,
            market_cap REAL,
            pe_ratio REAL,
            dividend_yield REAL,
            day_high REAL,
            day_low REAL,
            change_percent REAL,
            avg_volume INTEGER
        )
    ''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_symbol ON market_data(symbol)')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_timestamp ON market_data(timestamp)')
    conn.commit()
    return conn

def fetch_single_symbol(symbol):
    """Fetch data for a single symbol"""
    try:
        ticker = yf.Ticker(symbol)
        info = ticker.info
        hist = ticker.history(period='1d')
        
        if hist.empty:
            return None
        
        latest = hist.iloc[-1]
        
        return {
            'symbol': symbol,
            'price': float(latest['Close']),
            'volume': int(latest['Volume']),
            'market_cap': info.get('marketCap', None),
            'pe_ratio': info.get('trailingPE', None),
            'dividend_yield': info.get('dividendYield', None),
            'day_high': float(latest['High']),
            'day_low': float(latest['Low']),
            'change_percent': info.get('regularMarketChangePercent', 0.0),
            'avg_volume': info.get('averageVolume', None)
        }
    except Exception as e:
        logging.warning(f"Error fetching {symbol}: {e}")
        return None

def collect_batch_parallel(symbols, max_workers=32):
    """Collect data for multiple symbols in parallel"""
    results = []
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_symbol = {executor.submit(fetch_single_symbol, sym): sym for sym in symbols}
        for future in as_completed(future_to_symbol):
            result = future.result()
            if result:
                results.append(result)
    return results

def save_to_db(data_list):
    """Save collected data to database"""
    if not data_list:
        return 0
    
    conn = get_db_connection()
    cursor = conn.cursor()
    timestamp = datetime.now().isoformat()
    
    for data in data_list:
        cursor.execute('''
            INSERT INTO market_data 
            (timestamp, symbol, price, volume, market_cap, pe_ratio, dividend_yield, 
             day_high, day_low, change_percent, avg_volume)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            timestamp,
            data['symbol'],
            data['price'],
            data['volume'],
            data['market_cap'],
            data['pe_ratio'],
            data['dividend_yield'],
            data['day_high'],
            data['day_low'],
            data['change_percent'],
            data['avg_volume']
        ))
    
    conn.commit()
    conn.close()
    return len(data_list)

def main():
    """Main collection loop - 84 hours"""
    duration_hours = 84
    interval_minutes = 5
    
    start_time = datetime.now()
    end_time = start_time + timedelta(hours=duration_hours)
    
    logging.info("=" * 60)
    logging.info(f"Starting ADVANCED Data Collector - {duration_hours} hours")
    logging.info(f"Total assets: {len(SYMBOLS)}")
    logging.info(f"CPU Cores available: {multiprocessing.cpu_count()}")
    logging.info(f"Max parallel workers: 32")
    logging.info("=" * 60)
    
    iteration = 0
    
    while datetime.now() < end_time:
        iteration += 1
        iter_start = datetime.now()
        remaining = (end_time - iter_start).total_seconds() / 3600
        
        logging.info("")
        logging.info(f"Iteration #{iteration} - {iter_start.strftime('%Y-%m-%d %H:%M:%S')}")
        logging.info(f"Remaining: {remaining:.1f} hours")
        
        # Collect data in parallel batches
        batch_size = 50
        total_saved = 0
        
        for i in range(0, len(SYMBOLS), batch_size):
            batch = SYMBOLS[i:i+batch_size]
            batch_num = i // batch_size + 1
            
            batch_data = collect_batch_parallel(batch, max_workers=32)
            saved = save_to_db(batch_data)
            total_saved += saved
            
            logging.info(f"  Batch {batch_num}: {saved}/{len(batch)} records saved")
        
        iter_end = datetime.now()
        iter_duration = (iter_end - iter_start).total_seconds()
        
        logging.info(f"Iteration complete: {total_saved} records in {iter_duration:.1f}s")
        
        # Wait until next interval
        elapsed = (datetime.now() - iter_start).total_seconds()
        wait_time = (interval_minutes * 60) - elapsed
        
        if wait_time > 0:
            logging.info(f"Waiting {wait_time/60:.1f} minutes...")
            time.sleep(wait_time)
    
    logging.info("=" * 60)
    logging.info("Data collection completed!")
    logging.info("=" * 60)

if __name__ == '__main__':
    main()
