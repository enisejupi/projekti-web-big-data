"""
Database Manager for Financial Data Storage
Handles all database operations using PostgreSQL
"""

import psycopg2
from psycopg2.extras import execute_values
from sqlalchemy import create_engine
import pandas as pd
from typing import List, Dict, Optional
import logging
from contextlib import contextmanager

logger = logging.getLogger(__name__)


class DatabaseManager:
    """Menaxhon te gjitha operacionet me database"""
    
    def __init__(self, host='10.0.0.4', port=5432, 
                 dbname='financial_data', user='financeuser', 
                 password='Finance@2025!Secure'):
        """Inicializimi i lidhjes me database"""
        
        self.conn_params = {
            'host': host,
            'port': port,
            'dbname': dbname,
            'user': user,
            'password': password
        }
        
        # SQLAlchemy engine per Pandas integration
        self.engine = create_engine(
            f'postgresql://{user}:{password}@{host}:{port}/{dbname}',
            pool_size=20,
            max_overflow=40,
            pool_timeout=30
        )
        
        logger.info(f"Database connection initialized: {host}:{port}/{dbname}")
    
    @contextmanager
    def get_connection(self):
        """Context manager per lidhje me database"""
        conn = psycopg2.connect(**self.conn_params)
        try:
            yield conn
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            conn.close()
    
    def insert_market_data(self, df: pd.DataFrame):
        """
        Vendos te dhenat e tregut ne database
        
        Args:
            df: DataFrame me kolonat: symbol, timestamp, open, high, low, close, volume, etc.
        """
        try:
            df.to_sql(
                'market_data', 
                self.engine, 
                if_exists='append', 
                index=False,
                method='multi',
                chunksize=1000
            )
            logger.info(f"Inserted {len(df)} market data records")
        except Exception as e:
            logger.error(f"Error inserting market data: {e}")
            raise
    
    def insert_predictions(self, df: pd.DataFrame):
        """Vendos parashikimet e ML ne database"""
        try:
            df.to_sql(
                'ml_predictions',
                self.engine,
                if_exists='append',
                index=False,
                method='multi',
                chunksize=500
            )
            logger.info(f"Inserted {len(df)} prediction records")
        except Exception as e:
            logger.error(f"Error inserting predictions: {e}")
            raise
    
    def insert_recommendations(self, df: pd.DataFrame):
        """Vendos rekomandimet e investimit ne database"""
        try:
            df.to_sql(
                'investment_recommendations',
                self.engine,
                if_exists='append',
                index=False,
                method='multi',
                chunksize=500
            )
            logger.info(f"Inserted {len(df)} recommendation records")
        except Exception as e:
            logger.error(f"Error inserting recommendations: {e}")
            raise
    
    def insert_cluster_analysis(self, df: pd.DataFrame):
        """Vendos analizen e clustereve ne database"""
        try:
            df.to_sql(
                'cluster_analysis',
                self.engine,
                if_exists='append',
                index=False,
                method='multi',
                chunksize=500
            )
            logger.info(f"Inserted {len(df)} cluster analysis records")
        except Exception as e:
            logger.error(f"Error inserting cluster analysis: {e}")
            raise
    
    def get_latest_market_data(self, symbol: str, limit: int = 100) -> pd.DataFrame:
        """Merr te dhenat me te fundit te tregut per nje symbol"""
        query = """
            SELECT * FROM market_data 
            WHERE symbol = %s 
            ORDER BY timestamp DESC 
            LIMIT %s
        """
        return pd.read_sql_query(query, self.engine, params=(symbol, limit))
    
    def get_all_symbols(self) -> List[str]:
        """Merr listen e te gjitha simboleve"""
        query = "SELECT DISTINCT symbol FROM market_data ORDER BY symbol"
        df = pd.read_sql_query(query, self.engine)
        return df['symbol'].tolist()
    
    def get_predictions_summary(self, hours: int = 24) -> pd.DataFrame:
        """Merr permbledhjen e parashikimeve per X oret e fundit"""
        query = """
            SELECT 
                symbol,
                COUNT(*) as prediction_count,
                AVG(confidence_score) as avg_confidence,
                AVG(ABS(error)) as avg_error
            FROM ml_predictions
            WHERE timestamp >= NOW() - INTERVAL '%s hours'
            GROUP BY symbol
            ORDER BY avg_confidence DESC
        """
        return pd.read_sql_query(query, self.engine, params=(hours,))
    
    def get_top_recommendations(self, limit: int = 20) -> pd.DataFrame:
        """Merr rekomandimet me te mira"""
        query = """
            SELECT * FROM investment_recommendations
            WHERE timestamp >= NOW() - INTERVAL '1 hour'
            ORDER BY invest_score DESC
            LIMIT %s
        """
        return pd.read_sql_query(query, self.engine, params=(limit,))
    
    def cleanup_old_data(self, days: int = 90):
        """Fshin te dhenat me te vjetra se X dite"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            tables = ['market_data', 'ml_predictions', 'investment_recommendations', 'cluster_analysis']
            
            for table in tables:
                cursor.execute(f"""
                    DELETE FROM {table}
                    WHERE created_at < NOW() - INTERVAL '%s days'
                """, (days,))
                deleted = cursor.rowcount
                logger.info(f"Deleted {deleted} old records from {table}")
    
    def get_database_stats(self) -> Dict:
        """Merr statistikat e database"""
        query = """
            SELECT 
                'market_data' as table_name,
                COUNT(*) as row_count,
                COUNT(DISTINCT symbol) as unique_symbols,
                MIN(timestamp) as earliest_date,
                MAX(timestamp) as latest_date
            FROM market_data
            UNION ALL
            SELECT 
                'ml_predictions',
                COUNT(*),
                COUNT(DISTINCT symbol),
                MIN(timestamp),
                MAX(timestamp)
            FROM ml_predictions
            UNION ALL
            SELECT 
                'investment_recommendations',
                COUNT(*),
                COUNT(DISTINCT symbol),
                MIN(timestamp),
                MAX(timestamp)
            FROM investment_recommendations
        """
        df = pd.read_sql_query(query, self.engine)
        return df.to_dict('records')


# Global database instance
db = DatabaseManager()
