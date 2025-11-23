"""
Mbledhja e të Dhënave në Kohë Reale nga Yahoo Finance
Përdor PySpark Streaming për të mbledhur të dhëna për qindra asete
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import *
from pyspark.sql.types import *
import yfinance as yf
import pandas as pd
from datetime import datetime, timedelta
import time
import json
from typing import List, Dict
import logging

# Konfigurimi i logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/financial-analysis/logs/data_collector.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class FinancialDataCollector:
    """Kolektori i të dhënave financiare në kohë reale"""
    
    def __init__(self, spark_master="spark://10.0.0.4:7077"):
        """Inicializimi i Spark Session"""
        logger.info("Duke inicializuar Spark Session...")
        
        self.spark = SparkSession.builder \
            .appName("FinancialDataCollector") \
            .master(spark_master) \
            .config("spark.executor.memory", "130g") \
            .config("spark.driver.memory", "120g") \
            .config("spark.executor.cores", "16") \
            .config("spark.default.parallelism", "256") \
            .config("spark.sql.shuffle.partitions", "256") \
            .getOrCreate()
        
        self.spark.sparkContext.setLogLevel("WARN")
        logger.info("Spark Session u krijua me sukses")
        
        # Lista e aseteve për të mbledhur (PA kriptovaluta)
        self.assets = self._get_asset_list()
        logger.info(f"U ngarkuan {len(self.assets)} asete për mbledhje")
    
    def _get_asset_list(self) -> List[str]:
        """Merr listën e aseteve për të mbledhur të dhëna"""
        
        assets = []
        
        # Aksionet e S&P 500 (Top 100 më të mëdha)
        sp500_top = [
            'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'META', 'TSLA', 'BRK-B', 'UNH', 'JNJ',
            'V', 'PG', 'JPM', 'MA', 'HD', 'CVX', 'MRK', 'ABBV', 'PEP', 'KO',
            'AVGO', 'COST', 'PFE', 'TMO', 'MCD', 'CSCO', 'ABT', 'ACN', 'DHR', 'LIN',
            'ADBE', 'NKE', 'WMT', 'NEE', 'CRM', 'TXN', 'BMY', 'CMCSA', 'PM', 'HON',
            'QCOM', 'RTX', 'UPS', 'IBM', 'AMGN', 'SBUX', 'BA', 'CAT', 'GE', 'AMD',
            'INTC', 'INTU', 'AMAT', 'T', 'LOW', 'GS', 'BLK', 'NOW', 'DE', 'SPGI',
            'LMT', 'MDLZ', 'AXP', 'SYK', 'BKNG', 'GILD', 'ADP', 'MMC', 'TJX', 'C',
            'CVS', 'PLD', 'ISRG', 'ZTS', 'CB', 'MMM', 'CI', 'ADI', 'SO', 'MO',
            'DUK', 'BDX', 'SHW', 'CL', 'EOG', 'ITW', 'ICE', 'USB', 'NOC', 'PNC',
            'REGN', 'APD', 'CME', 'GD', 'EMR', 'TGT', 'HUM', 'NSC', 'COF', 'BSX'
        ]
        assets.extend(sp500_top)
        
        # Aksione evropiane (Top 50)
        european_stocks = [
            'MC.PA', 'ASML.AS', 'OR.PA', 'SAP.DE', 'RMS.PA', 'SIE.DE', 'NOVO-B.CO',
            'AZN.L', 'AI.PA', 'SAN.PA', 'TTE.PA', 'ALV.DE', 'AIR.PA', 'BN.PA',
            'SHEL.L', 'SU.PA', 'BBVA.MC', 'IBE.MC', 'BNP.PA', 'DTE.DE', 'VOW3.DE',
            'ENEL.MI', 'ITX.MC', 'ABI.BR', 'ADYEN.AS', 'DG.PA', 'EN.PA', 'CS.PA',
            'SGO.PA', 'VIV.PA', 'MT.AS', 'GLEN.L', 'BP.L', 'HSBA.L', 'ULVR.L',
            'GSK.L', 'DGE.L', 'NG.L', 'BARC.L', 'LLOY.L', 'VOD.L', 'PRU.L',
            'RIO.L', 'BHP.L', 'AAL.L', 'BATS.L', 'RKT.L', 'REL.L', 'AV.L', 'BA.L'
        ]
        assets.extend(european_stocks)
        
        # Aksione aziatike (Top 30)
        asian_stocks = [
            '7203.T', '6758.T', '9984.T', '6861.T', '9433.T', '8306.T', '6902.T',
            '005930.KS', '000660.KS', '035720.KS', '051910.KS', '035420.KS',
            '0700.HK', '9988.HK', '0941.HK', '1299.HK', '3690.HK', '1810.HK',
            '2318.HK', '0388.HK', '0939.HK', '1398.HK', '0883.HK', '2628.HK',
            'RELIANCE.NS', 'TCS.NS', 'HDFCBANK.NS', 'INFY.NS', 'HINDUNILVR.NS',
            'ICICIBANK.NS'
        ]
        assets.extend(asian_stocks)
        
        # Indekset kryesore
        indices = [
            '^GSPC', '^DJI', '^IXIC', '^RUT', '^VIX',  # US
            '^FTSE', '^GDAXI', '^FCHI', '^STOXX50E',  # Europe
            '^N225', '^HSI', '000001.SS', '^STI',  # Asia
        ]
        assets.extend(indices)
        
        # Mallrat (Commodities)
        commodities = [
            'GC=F',  # Ari
            'SI=F',  # Argjendi
            'CL=F',  # Nafta Crude
            'BZ=F',  # Nafta Brent
            'NG=F',  # Gazi Natyror
            'HG=F',  # Bakri
            'PL=F',  # Platinumi
            'PA=F',  # Palladiumi
            'ZC=F',  # Misri
            'ZS=F',  # Soja
            'ZW=F',  # Gruri
            'KC=F',  # Kafeja
            'CC=F',  # Kakaoja
            'SB=F',  # Sheqeri
            'CT=F',  # Pambuku
        ]
        assets.extend(commodities)
        
        # Forex (Top Pairs)
        forex = [
            'EURUSD=X', 'GBPUSD=X', 'JPYUSD=X', 'AUDUSD=X', 'NZDUSD=X',
            'USDCAD=X', 'USDCHF=X', 'EURGBP=X', 'EURJPY=X', 'GBPJPY=X',
            'EURCAD=X', 'EURCHF=X', 'EURAUD=X', 'EURNZD=X', 'GBPAUD=X',
            'GBPCAD=X', 'GBPCHF=X', 'AUDCAD=X', 'AUDCHF=X', 'AUDJPY=X',
            'AUDNZD=X', 'CADCHF=X', 'CADJPY=X', 'CHFJPY=X', 'NZDCAD=X',
            'NZDCHF=X', 'NZDJPY=X'
        ]
        assets.extend(forex)
        
        # ETFs të rëndësishme
        etfs = [
            'SPY', 'QQQ', 'DIA', 'IWM', 'EEM', 'EFA', 'GLD', 'SLV',
            'TLT', 'IEF', 'LQD', 'HYG', 'XLF', 'XLE', 'XLK', 'XLV',
            'XLI', 'XLP', 'XLU', 'XLB', 'XLY', 'XLRE', 'VTI', 'VEA',
            'VWO', 'AGG', 'BND', 'VNQ', 'GDX', 'USO'
        ]
        assets.extend(etfs)
        
        return list(set(assets))  # Heq dublikatat
    
    def fetch_batch_data(self, symbols: List[str]) -> pd.DataFrame:
        """Merr të dhënat për një grup simbolesh"""
        try:
            # Përdor periudhën 5d për të marrë të dhëna të fundit
            data = yf.download(
                symbols,
                period='5d',
                interval='5m',
                group_by='ticker',
                threads=True,
                progress=False
            )
            
            if data.empty:
                logger.warning(f"Nuk u gjeten të dhëna për: {symbols[:5]}...")
                return pd.DataFrame()
            
            # Konverto në format të përdorshëm
            records = []
            timestamp = datetime.now()
            
            for symbol in symbols:
                try:
                    if len(symbols) == 1:
                        symbol_data = data
                    else:
                        symbol_data = data[symbol]
                    
                    if not symbol_data.empty:
                        latest = symbol_data.iloc[-1]
                        
                        # Llogarit statistikat
                        daily_return = ((latest['Close'] - symbol_data.iloc[0]['Open']) / 
                                       symbol_data.iloc[0]['Open'] * 100)
                        
                        volatility = symbol_data['Close'].pct_change().std() * 100
                        
                        avg_volume = symbol_data['Volume'].mean()
                        
                        records.append({
                            'symbol': symbol,
                            'timestamp': timestamp,
                            'open': float(latest['Open']),
                            'high': float(latest['High']),
                            'low': float(latest['Low']),
                            'close': float(latest['Close']),
                            'volume': float(latest['Volume']),
                            'daily_return': float(daily_return),
                            'volatility': float(volatility),
                            'avg_volume': float(avg_volume),
                            'ma_5': float(symbol_data['Close'].tail(5).mean()),
                            'ma_20': float(symbol_data['Close'].tail(20).mean()),
                        })
                
                except Exception as e:
                    logger.error(f"Gabim në përpunimin e {symbol}: {e}")
                    continue
            
            return pd.DataFrame(records)
        
        except Exception as e:
            logger.error(f"Gabim në mbledhjen e të dhënave: {e}")
            return pd.DataFrame()
    
    def collect_realtime_data(self, duration_hours: float = 84.0, interval_minutes: int = 5):
        """
        Mbledh të dhëna në kohë reale për kohëzgjatjen e specifikuar
        
        Args:
            duration_hours: Kohëzgjatja totale (default 84 = 3.5 ditë)
            interval_minutes: Intervali i mbledhjes në minuta (default 5)
        """
        logger.info("="*60)
        logger.info("Fillimi i Mbledhjes së të Dhënave në Kohë Reale")
        logger.info("="*60)
        logger.info(f"Kohëzgjatja: {duration_hours} orë ({duration_hours/24:.1f} ditë)")
        logger.info(f"Intervali: {interval_minutes} minuta")
        logger.info(f"Numri i aseteve: {len(self.assets)}")
        logger.info("="*60)
        
        end_time = datetime.now() + timedelta(hours=duration_hours)
        batch_size = 50  # Merr 50 asete në një herë për performancë
        iteration = 0
        
        while datetime.now() < end_time:
            iteration += 1
            start = datetime.now()
            
            logger.info(f"\n{'='*60}")
            logger.info(f"Iteracioni #{iteration} - {start.strftime('%Y-%m-%d %H:%M:%S')}")
            logger.info(f"Mbetet: {(end_time - start).total_seconds() / 3600:.1f} orë")
            logger.info(f"{'='*60}\n")
            
            all_data = []
            
            # Mbledh të dhënat në batch
            for i in range(0, len(self.assets), batch_size):
                batch = self.assets[i:i+batch_size]
                logger.info(f"Duke mbledhur batch {i//batch_size + 1}/{(len(self.assets)-1)//batch_size + 1}")
                
                df_batch = self.fetch_batch_data(batch)
                if not df_batch.empty:
                    all_data.append(df_batch)
                
                time.sleep(1)  # Pauza të vogël për të shmangur rate limiting
            
            # Bashko të gjitha të dhënat
            if all_data:
                df_combined = pd.concat(all_data, ignore_index=True)
                
                # Konverto në Spark DataFrame
                spark_df = self.spark.createDataFrame(df_combined)
                
                # Ruaj në Parquet për përpunim të shpejtë
                output_path = f"/opt/financial-analysis/data/raw/batch_{start.strftime('%Y%m%d_%H%M%S')}.parquet"
                spark_df.write.mode('overwrite').parquet(output_path)
                
                logger.info(f"✓ U ruajtën {len(df_combined)} rekorde në {output_path}")
                logger.info(f"  Asetet e përpunuara: {df_combined['symbol'].nunique()}")
                logger.info(f"  Koha e përpunimit: {(datetime.now() - start).total_seconds():.1f}s")
            else:
                logger.warning("Nuk u mbledhën të dhëna në këtë iteracion")
            
            # Prit deri në iteracionin e ardhshëm
            elapsed = (datetime.now() - start).total_seconds()
            wait_time = max(0, interval_minutes * 60 - elapsed)
            
            if wait_time > 0:
                logger.info(f"\nDuke pritur {wait_time/60:.1f} minuta deri në iteracionin e ardhshëm...")
                time.sleep(wait_time)
        
        logger.info("\n" + "="*60)
        logger.info("Mbledhja e të dhënave u përfundua me sukses!")
        logger.info(f"Iteracionet totale: {iteration}")
        logger.info("="*60)
    
    def stop(self):
        """Ndal Spark Session"""
        logger.info("Duke ndalur Spark Session...")
        self.spark.stop()
        logger.info("Spark Session u ndal")


if __name__ == "__main__":
    collector = FinancialDataCollector()
    
    try:
        # Mbledh të dhëna për 3.5 ditë, çdo 5 minuta
        collector.collect_realtime_data(duration_hours=84.0, interval_minutes=5)
    except KeyboardInterrupt:
        logger.info("\nU ndërpre nga përdoruesi")
    except Exception as e:
        logger.error(f"Gabim kritik: {e}")
    finally:
        collector.stop()
