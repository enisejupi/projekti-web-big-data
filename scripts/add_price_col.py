#!/usr/bin/env python3.9
import sqlite3
conn = sqlite3.connect('/opt/financial-analysis/data/market_data.db')
try:
    conn.execute('ALTER TABLE market_data ADD COLUMN price REAL')
    print('✅ Price column added')
except:
    print('⚠️ Price column already exists')
conn.execute('UPDATE market_data SET price = close WHERE price IS NULL')
conn.commit()
print('✅ Price values populated from close')
conn.close()
