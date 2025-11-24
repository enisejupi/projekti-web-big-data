#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
Simple Synthetic Data Generator for Testing
Generates realistic financial market data for ML training
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from datetime import datetime, timedelta
import random
import time

def generate_synthetic_data():
    """Generate synthetic financial data"""
    
    # Initialize Spark
    spark = SparkSession.builder \
        .appName("SyntheticDataGenerator") \
        .master("spark://10.0.0.4:7077") \
        .config("spark.executor.memory", "8g") \
        .config("spark.driver.memory", "4g") \
        .config("spark.executor.cores", "4") \
        .getOrCreate()
    
    print("=" * 50)
    print("Generating Synthetic Financial Data")
    print("=" * 50)
    
    # Generate data for 50 symbols over 30 days
    symbols = [
        'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK-B', 'UNH', 'JNJ',
        'XOM', 'JPM', 'V', 'PG', 'MA', 'HD', 'CVX', 'MRK', 'ABBV', 'PEP',
        'AVGO', 'COST', 'KO', 'ADBE', 'TMO', 'WMT', 'MCD', 'CSCO', 'ACN', 'ABT',
        'NKE', 'LIN', 'NFLX', 'CRM', 'DIS', 'VZ', 'CMCSA', 'DHR', 'TXN', 'INTC',
        'NEE', 'PM', 'RTX', 'ORCL', 'AMD', 'UNP', 'WFC', 'HON', 'QCOM', 'MS'
    ]
    
    # Base prices for each symbol
    base_prices = {
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
    
    # Generate 30 days of data
    data = []
    start_date = datetime.now() - timedelta(days=30)
    
    print("\nGenerating data for 30 days across 50 symbols...")
    print(f"Total records to generate: {30 * 50 * 24} (hourly data)")
    
    for day_offset in range(30):
        current_date = start_date + timedelta(days=day_offset)
        
        for symbol in symbols:
            base_price = base_prices[symbol]
            
            # Generate hourly data (24 hours)
            for hour in range(24):
                timestamp = current_date + timedelta(hours=hour)
                
                # Random price movement
                price = base_price * (1 + random.uniform(-0.02, 0.02))
                volume = random.randint(1000000, 50000000)
                
                # Technical indicators
                open_price = price * (1 + random.uniform(-0.005, 0.005))
                high_price = max(open_price, price) * (1 + random.uniform(0, 0.01))
                low_price = min(open_price, price) * (1 + random.uniform(-0.01, 0))
                close_price = price
                
                data.append({
                    'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S'),
                    'symbol': symbol,
                    'open': round(open_price, 2),
                    'high': round(high_price, 2),
                    'low': round(low_price, 2),
                    'close': round(close_price, 2),
                    'volume': volume,
                    'market_cap': round(price * volume / 1000, 2)
                })
        
        if (day_offset + 1) % 5 == 0:
            print(f"  Progress: {day_offset + 1}/30 days completed")
    
    print(f"\n✓ Generated {len(data)} records")
    
    # Create DataFrame
    df = spark.createDataFrame(data)
    
    # Save as parquet
    output_path = "/opt/financial-analysis/data/raw"
    print(f"\nSaving data to {output_path}...")
    
    df.write \
        .mode("overwrite") \
        .parquet(output_path)
    
    print(f"✓ Data saved successfully!")
    
    # Show statistics
    print("\n" + "=" * 50)
    print("Data Statistics")
    print("=" * 50)
    df.groupBy("symbol").count().orderBy("symbol").show(10)
    
    print("\nSample data:")
    df.orderBy("timestamp").show(20, truncate=False)
    
    print("\n" + "=" * 50)
    print("✓ Synthetic data generation complete!")
    print(f"  Total records: {df.count()}")
    print(f"  Symbols: {df.select('symbol').distinct().count()}")
    print(f"  Date range: {df.agg(min('timestamp'), max('timestamp')).collect()[0]}")
    print("=" * 50)
    
    spark.stop()

if __name__ == "__main__":
    generate_synthetic_data()
