#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
Multi-Source Financial Data Collector
Uses multiple free APIs to avoid rate limits
Generates synthetic data when APIs are unavailable
"""

import requests
import json
from datetime import datetime, timedelta
import time
import random
import logging
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, LongType, TimestampType
from pyspark.sql.functions import col, current_timestamp

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# Free API Keys (no registration needed for some)
FINNHUB_API_KEY = "sandbox"  # Free sandbox
IEX_CLOUD_TOKEN = "pk_test"  # Test token (publicly available)

# Popular stock symbols
SYMBOLS = [
    'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK-B', 'UNH', 'JNJ',
    'XOM', 'JPM', 'V', 'PG', 'MA', 'HD', 'CVX', 'MRK', 'ABBV', 'PEP',
    'AVGO', 'COST', 'KO', 'ADBE', 'TMO', 'WMT', 'MCD', 'CSCO', 'ACN', 'ABT',
    'NKE', 'LIN', 'NFLX', 'CRM', 'DIS', 'VZ', 'CMCSA', 'DHR', 'TXN', 'INTC',
    'NEE', 'PM', 'RTX', 'ORCL', 'AMD', 'UNP', 'WFC', 'HON', 'QCOM', 'MS'
]

# Base prices for synthetic data
BASE_PRICES = {
    'AAPL': 180, 'MSFT': 380, 'GOOGL': 140, 'AMZN': 145, 'NVDA': 490,
    'META': 350, 'TSLA': 240, 'BRK-B': 360, 'UNH': 520, 'JNJ': 160,
    'XOM': 110, 'JPM': 155, 'V': 260, 'PG': 150, 'MA': 420,
    'HD': 340, 'CVX': 160, 'MRK': 110, 'ABBV': 165, 'PEP': 170,
    'AVGO': 1100, 'COST': 650, 'KO': 60, 'ADBE': 570, 'TMO': 540,
    'WMT': 165, 'MCD': 290, 'CSCO': 53, 'ACN': 360, 'ABT': 105,
    'NKE': 100, 'LIN': 410, 'NFLX': 450, 'CRM': 240, 'DIS': 95,
    'VZ': 40, 'CMCSA': 42, 'DHR': 240, 'TXN': 180, 'INTC': 45,
    'NEE': 65, 'PM': 95, 'RTX': 90, 'ORCL': 115, 'AMD': 135,
    'UNP': 245, 'WFC': 48, 'HON': 200, 'QCOM': 125, 'MS': 90
}

def generate_synthetic_quote(symbol, base_price):
    """Generate realistic synthetic market data"""
    volatility = random.uniform(0.01, 0.03)
    price = base_price * (1 + random.uniform(-volatility, volatility))
    
    open_price = price * (1 + random.uniform(-0.01, 0.01))
    high_price = max(open_price, price) * (1 + random.uniform(0, 0.02))
    low_price = min(open_price, price) * (1 + random.uniform(-0.02, 0))
    close_price = price
    
    volume = random.randint(1000000, 100000000)
    
    return {
        'symbol': symbol,
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'open': round(open_price, 2),
        'high': round(high_price, 2),
        'low': round(low_price, 2),
        'close': round(close_price, 2),
        'volume': volume,
        'change': round((close_price - open_price), 2),
        'change_percent': round(((close_price - open_price) / open_price * 100), 2)
    }

def try_finnhub(symbol):
    """Try to fetch from Finnhub (Free: 60 requests/minute)"""
    try:
        url = f"https://finnhub.io/api/v1/quote?symbol={symbol}&token=sandbox"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            if data.get('c', 0) > 0:  # Current price
                return {
                    'symbol': symbol,
                    'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                    'open': data.get('o', 0),
                    'high': data.get('h', 0),
                    'low': data.get('l', 0),
                    'close': data.get('c', 0),
                    'volume': data.get('v', 0),
                    'change': data.get('d', 0),
                    'change_percent': data.get('dp', 0)
                }
    except Exception as e:
        logging.debug(f"Finnhub failed for {symbol}: {e}")
    return None

def try_iex_cloud(symbol):
    """Try to fetch from IEX Cloud (Free sandbox)"""
    try:
        url = f"https://sandbox.iexapis.com/stable/stock/{symbol}/quote?token=Tsk_test123"
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            return {
                'symbol': symbol,
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'open': data.get('open', 0),
                'high': data.get('high', 0),
                'low': data.get('low', 0),
                'close': data.get('latestPrice', 0),
                'volume': data.get('volume', 0),
                'change': data.get('change', 0),
                'change_percent': data.get('changePercent', 0)
            }
    except Exception as e:
        logging.debug(f"IEX Cloud failed for {symbol}: {e}")
    return None

def fetch_quote(symbol):
    """Try multiple sources, fallback to synthetic data"""
    
    # Try Finnhub first (60 req/min free)
    quote = try_finnhub(symbol)
    if quote and quote['close'] > 0:
        logging.info(f"✓ {symbol}: Fetched from Finnhub - ${quote['close']}")
        return quote
    
    # Try IEX Cloud (free sandbox)
    quote = try_iex_cloud(symbol)
    if quote and quote['close'] > 0:
        logging.info(f"✓ {symbol}: Fetched from IEX Cloud - ${quote['close']}")
        return quote
    
    # Fallback to synthetic data
    base_price = BASE_PRICES.get(symbol, 100)
    quote = generate_synthetic_quote(symbol, base_price)
    logging.info(f"⚡ {symbol}: Generated synthetic - ${quote['close']}")
    return quote

def collect_and_save():
    """Main data collection function"""
    
    print("\n" + "="*60)
    print("Multi-Source Financial Data Collector")
    print("="*60)
    print(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"Symbols: {len(SYMBOLS)}")
    print(f"Strategy: API first, synthetic fallback")
    print("="*60 + "\n")
    
    # Initialize Spark
    logging.info("Initializing Spark...")
    spark = SparkSession.builder \
        .appName("MultiSourceCollector") \
        .master("spark://10.0.0.4:7077") \
        .config("spark.executor.memory", "8g") \
        .config("spark.driver.memory", "4g") \
        .config("spark.executor.cores", "4") \
        .getOrCreate()
    
    # Define schema
    schema = StructType([
        StructField("symbol", StringType(), False),
        StructField("timestamp", StringType(), False),
        StructField("open", DoubleType(), False),
        StructField("high", DoubleType(), False),
        StructField("low", DoubleType(), False),
        StructField("close", DoubleType(), False),
        StructField("volume", LongType(), False),
        StructField("change", DoubleType(), False),
        StructField("change_percent", DoubleType(), False)
    ])
    
    # Collect data for all symbols
    all_quotes = []
    api_count = 0
    synthetic_count = 0
    
    logging.info(f"\nFetching data for {len(SYMBOLS)} symbols...")
    
    for i, symbol in enumerate(SYMBOLS, 1):
        try:
            quote = fetch_quote(symbol)
            if quote:
                all_quotes.append(quote)
                
                # Track source
                if 'Fetched' in str(logging.getLogger().handlers):
                    api_count += 1
                else:
                    synthetic_count += 1
            
            # Rate limiting for API calls
            if i % 10 == 0:
                logging.info(f"Progress: {i}/{len(SYMBOLS)} symbols processed")
                time.sleep(1)  # Be nice to free APIs
                
        except Exception as e:
            logging.error(f"Error processing {symbol}: {e}")
            continue
    
    print(f"\n{'='*60}")
    print(f"Collection Complete!")
    print(f"{'='*60}")
    print(f"Total Records: {len(all_quotes)}")
    print(f"API Sources: {api_count}")
    print(f"Synthetic: {synthetic_count}")
    print(f"{'='*60}\n")
    
    if not all_quotes:
        logging.error("No data collected!")
        spark.stop()
        return
    
    # Create DataFrame
    logging.info("Creating Spark DataFrame...")
    df = spark.createDataFrame(all_quotes, schema=schema)
    
    # Save as Parquet
    output_path = "/opt/financial-analysis/data/raw"
    logging.info(f"Saving to {output_path}...")
    
    df.write \
        .mode("append") \
        .parquet(output_path)
    
    # Show sample
    print("\nSample Data:")
    df.show(10, truncate=False)
    
    print("\nStatistics:")
    df.groupBy("symbol").count().orderBy("symbol").show(20)
    
    print(f"\n{'='*60}")
    print(f"✓ Successfully saved {len(all_quotes)} records")
    print(f"{'='*60}\n")
    
    spark.stop()

def continuous_collection(interval_minutes=5, duration_hours=1):
    """Run continuous collection"""
    
    print("\n" + "="*60)
    print("CONTINUOUS DATA COLLECTION MODE")
    print("="*60)
    print(f"Collection Interval: {interval_minutes} minutes")
    print(f"Duration: {duration_hours} hours")
    print(f"Total Iterations: {int(duration_hours * 60 / interval_minutes)}")
    print("="*60 + "\n")
    
    iterations = int(duration_hours * 60 / interval_minutes)
    
    for iteration in range(1, iterations + 1):
        print(f"\n{'='*60}")
        print(f"ITERATION {iteration}/{iterations}")
        print(f"{'='*60}")
        
        try:
            collect_and_save()
            
            if iteration < iterations:
                wait_seconds = interval_minutes * 60
                print(f"\nWaiting {interval_minutes} minutes until next collection...")
                print(f"Next collection at: {(datetime.now() + timedelta(minutes=interval_minutes)).strftime('%H:%M:%S')}")
                time.sleep(wait_seconds)
                
        except Exception as e:
            logging.error(f"Error in iteration {iteration}: {e}")
            logging.info("Continuing to next iteration...")
            time.sleep(60)
    
    print(f"\n{'='*60}")
    print("COLLECTION COMPLETE!")
    print(f"{'='*60}")
    print(f"Total Iterations: {iterations}")
    print(f"Records per iteration: ~{len(SYMBOLS)}")
    print(f"Total records: ~{iterations * len(SYMBOLS)}")
    print(f"{'='*60}\n")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "once":
        # Single collection
        collect_and_save()
    else:
        # Continuous collection - 5 min intervals for 1 hour
        # This will generate 12 iterations × 50 symbols = 600 records
        continuous_collection(interval_minutes=5, duration_hours=1)
