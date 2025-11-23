"""
Skript për të kryer parashikime periodike dhe për t'i ruajtur
Ekzekutohet çdo 10 minuta për të përditësuar parashikimet
"""

from pyspark.sql import SparkSession
import sys
import os
import logging
from datetime import datetime

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


def run_predictions():
    """Ekzekuton parashikime dhe i ruan rezultatet"""
    logger.info("="*60)
    logger.info("Fillimi i Parashikimeve Periodike")
    logger.info("="*60)
    
    try:
        # Inicializo predictor
        predictor = MLPredictor()
        
        # Merr të dhënat më të fundit
        data_dir = "/opt/financial-analysis/data/raw"
        files = [f for f in os.listdir(data_dir) if f.endswith('.parquet')]
        
        if not files:
            logger.warning("Nuk u gjetën të dhëna për parashikim")
            return
        
        latest_file = sorted(files)[-1]
        data_path = f"{data_dir}/{latest_file}"
        
        logger.info(f"Duke ngarkuar të dhëna nga: {latest_file}")
        df = predictor.spark.read.parquet(data_path)
        
        # Përgatit features
        df = predictor.prepare_features(df)
        
        # Bëj parashikime me ensemble
        predictions = predictor.ensemble_predict(df)
        
        # Gjeneroni rekomandime
        recommendations = predictor.generate_recommendations(predictions)
        
        # Ruaj rezultatet
        output_path = "/opt/financial-analysis/data/predictions/latest_predictions.parquet"
        spark_recommendations = predictor.spark.createDataFrame(recommendations)
        spark_recommendations.write.mode('overwrite').parquet(output_path)
        
        logger.info(f"✓ Parashikimet u ruajtën në: {output_path}")
        logger.info(f"  Total predictions: {len(recommendations)}")
        logger.info(f"  Recommendations: {recommendations['recommendation'].value_counts().to_dict()}")
        
        # Ruaj edhe një kopje me timestamp
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        archive_path = f"/opt/financial-analysis/data/predictions/predictions_{timestamp}.parquet"
        spark_recommendations.write.mode('overwrite').parquet(archive_path)
        logger.info(f"✓ Arkivuar në: {archive_path}")
        
        predictor.spark.stop()
        
        logger.info("="*60)
        logger.info("Parashikimet u përfunduan me sukses")
        logger.info("="*60)
        
    except Exception as e:
        logger.error(f"Gabim në parashikime: {e}", exc_info=True)
        raise


if __name__ == "__main__":
    run_predictions()
