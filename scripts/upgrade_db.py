#!/usr/bin/env python3.9
"""
Database Schema Upgrade Script
Adds new columns to existing database
"""

import sqlite3

DB_PATH = '/opt/financial-analysis/data/market_data.db'

def upgrade_schema():
    """Upgrade database schema with new columns"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check existing columns
    cursor.execute("PRAGMA table_info(market_data)")
    existing_cols = [col[1] for col in cursor.fetchall()]
    print(f"Existing columns: {existing_cols}")
    
    # Add missing columns
    new_columns = [
        ('market_cap', 'REAL'),
        ('pe_ratio', 'REAL'),
        ('dividend_yield', 'REAL'),
        ('day_high', 'REAL'),
        ('day_low', 'REAL'),
        ('change_percent', 'REAL'),
        ('avg_volume', 'INTEGER')
    ]
    
    for col_name, col_type in new_columns:
        if col_name not in existing_cols:
            try:
                cursor.execute(f'ALTER TABLE market_data ADD COLUMN {col_name} {col_type}')
                print(f"✅ Added column: {col_name}")
            except Exception as e:
                print(f"⚠️  Column {col_name} already exists or error: {e}")
    
    conn.commit()
    conn.close()
    print("\n✅ Database schema upgraded successfully!")

if __name__ == '__main__':
    upgrade_schema()
