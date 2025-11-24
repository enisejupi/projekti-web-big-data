"""
Skript për të kryer parashikime periodike dhe për t'i ruajtur
Ekzekutohet çdo 10 minuta për të përditësuar parashikimet
FIXED VERSION - Handles corrupted parquet files and errors gracefully
"""

from pyspark.sql import SparkSession
import sys
import os
import logging
from datetime import datetime
import traceback

# Shto path për imports
sys.path.append('/opt/financial-analysis')

from ml_models.predictor import MLPredictor

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/financial-analysis/logs/periodic_predictions.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def validate_parquet_file(file_path):
    """Validate that a parquet file is readable and not empty"""
    try:
        import pyarrow.parquet as pq
        table = pq.read_table(file_path)
        
        if table.num_rows == 0:
            logger.warning(f"Parquet file is empty: {file_path}")
            return False
        
        if table.num_columns == 0:
            logger.warning(f"Parquet file has no columns: {file_path}")
            return False
        
        logger.info(f"Valid parquet: {file_path} ({table.num_rows} rows, {table.num_columns} cols)")
        return True
        
    except Exception as e:
        logger.error(f"Invalid parquet file {file_path}: {e}")
        return False


def find_valid_parquet_files(data_dir):
    """Find all valid parquet files in the directory"""
    valid_files = []
    
    try:
        all_files = [f for f in os.listdir(data_dir) if f.endswith('.parquet')]
        logger.info(f"Found {len(all_files)} parquet files in {data_dir}")
        
        for filename in sorted(all_files, reverse=True):  # newest first
            file_path = os.path.join(data_dir, filename)
            if validate_parquet_file(file_path):
                valid_files.append(file_path)
        
        logger.info(f"Found {len(valid_files)} valid parquet files")
        return valid_files
        
    except Exception as e:
        logger.error(f"Error scanning directory {data_dir}: {e}")
        return []


def run_predictions():
    """Ekzekuton parashikime dhe i ruan rezultatet"""
    logger.info("="*60)
    logger.info("Fillimi i Parashikimeve Periodike")
    logger.info("="*60)
    
    predictor = None
    
    try:
        # Inicializo predictor
        predictor = MLPredictor()
        
        # Find valid parquet files
        data_dir = "/opt/financial-analysis/data/raw"
        valid_files = find_valid_parquet_files(data_dir)
        
        if not valid_files:
            logger.warning("⚠ Nuk u gjetën të dhëna të vlefshme për parashikim")
            logger.warning("  Sigurohu që data collector është duke punuar dhe ka prodhuar të dhëna")
            return
        
        # Use the latest valid file
        data_path = valid_files[0]
        logger.info(f"Duke përdorur: {os.path.basename(data_path)}")
        
        # Load data with explicit error handling
        try:
            df = predictor.spark.read.parquet(data_path)
            record_count = df.count()
            
            if record_count == 0:
                logger.warning("⚠ Parquet file is empty, waiting for more data")
                return
            
            logger.info(f"✓ Loaded {record_count} records")
            
        except Exception as e:
            logger.error(f"✗ Failed to read parquet file: {e}")
            logger.info("  This file may be corrupted. Moving to backup...")
            
            # Move corrupted file to backup
            backup_dir = "/opt/financial-analysis/data/backup"
            os.makedirs(backup_dir, exist_ok=True)
            backup_path = os.path.join(backup_dir, f"corrupted_{os.path.basename(data_path)}")
            
            try:
                os.rename(data_path, backup_path)
                logger.info(f"  Moved corrupted file to: {backup_path}")
            except:
                pass
            
            # Try next valid file
            if len(valid_files) > 1:
                data_path = valid_files[1]
                logger.info(f"  Trying next file: {os.path.basename(data_path)}")
                df = predictor.spark.read.parquet(data_path)
            else:
                logger.error("  No other valid files available")
                return
        
        # Check if models exist
        models_dir = "/opt/financial-analysis/models"
        rf_model_path = f"{models_dir}/random_forest"
        gbt_model_path = f"{models_dir}/gradient_boosting"
        
        models_exist = os.path.exists(rf_model_path) and os.path.exists(gbt_model_path)
        
        if not models_exist:
            logger.warning("⚠ ML models not found. Models need to be trained first.")
            logger.info("  Please run the training script: python3.9 /opt/financial-analysis/ml_models/predictor.py")
            logger.info("  Or train models from the dashboard")
            return
        
        # Përgatit features
        logger.info("Duke përgatitur features...")
        df = predictor.prepare_features(df)
        feature_count = df.count()
        logger.info(f"✓ Prepared {feature_count} feature rows")
        
        if feature_count == 0:
            logger.warning("⚠ No features after preparation (not enough historical data)")
            return
        
        # Bëj parashikime me ensemble
        logger.info("Duke bërë parashikime...")
        predictions = predictor.ensemble_predict(df)
        
        # Gjeneroni rekomandime
        logger.info("Duke gjeneruar rekomandime...")
        recommendations = predictor.generate_recommendations(predictions)
        
        # Ruaj rezultatet
        output_dir = "/opt/financial-analysis/data/predictions"
        os.makedirs(output_dir, exist_ok=True)
        
        output_path = f"{output_dir}/latest_predictions.parquet"
        spark_recommendations = predictor.spark.createDataFrame(recommendations)
        spark_recommendations.write.mode('overwrite').parquet(output_path)
        
        logger.info(f"✓ Parashikimet u ruajtën në: {output_path}")
        logger.info(f"  Total predictions: {len(recommendations)}")
        
        if 'recommendation' in recommendations.columns:
            rec_counts = recommendations['recommendation'].value_counts().to_dict()
            logger.info(f"  Recommendations: {rec_counts}")
        
        # Ruaj edhe një kopje me timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        archive_path = f"{output_dir}/predictions_{timestamp}.parquet"
        spark_recommendations.write.mode('overwrite').parquet(archive_path)
        logger.info(f"✓ Arkivuar në: {archive_path}")
        
        logger.info("="*60)
        logger.info("✓ Parashikimet u përfunduan me sukses")
        logger.info("="*60)
        
    except Exception as e:
        logger.error("="*60)
        logger.error(f"✗ Gabim në parashikime: {e}")
        logger.error("="*60)
        logger.error(traceback.format_exc())
        
        # Don't raise - let cron continue
        
    finally:
        # Always clean up Spark session
        if predictor and predictor.spark:
            try:
                predictor.spark.stop()
                logger.info("Spark session closed")
            except:
                pass


if __name__ == "__main__":
    run_predictions()
