"""
Modelet e Machine Learning për Parashikim të Çmimeve
Kombinon algoritme të mbikëqyrur dhe jo të mbikëqyrur
Target: 90%+ saktësi
"""

from pyspark.sql import SparkSession
from pyspark.ml import Pipeline
from pyspark.ml.feature import VectorAssembler, StandardScaler, PCA
from pyspark.ml.regression import RandomForestRegressor, GBTRegressor, LinearRegression
from pyspark.ml.clustering import KMeans
from pyspark.ml.evaluation import RegressionEvaluator
from pyspark.sql.functions import *
from pyspark.sql.window import Window
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.metrics import mean_absolute_percentage_error, r2_score
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import pickle
import logging
from datetime import datetime, timedelta
from typing import Dict, Tuple, List
import json

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/opt/financial-analysis/logs/ml_predictor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class MLPredictor:
    """Sistemi i parashikimit me Machine Learning"""
    
    def __init__(self, spark_master="spark://10.0.0.4:7077"):
        """Inicializimi"""
        logger.info("Duke inicializuar ML Predictor...")
        
        self.spark = SparkSession.builder \
            .appName("MLPredictor") \
            .master(spark_master) \
            .config("spark.executor.memory", "130g") \
            .config("spark.driver.memory", "120g") \
            .config("spark.executor.cores", "16") \
            .config("spark.sql.adaptive.enabled", "true") \
            .getOrCreate()
        
        self.spark.sparkContext.setLogLevel("WARN")
        
        self.models = {}
        self.model_performance = {}
        
        logger.info("ML Predictor u inicializua")
    
    def prepare_features(self, df):
        """
        Përgatit features për ML models
        Krijon indikatorë teknikë dhe transformon të dhënat
        """
        logger.info("Duke përgatitur features...")
        
        # Rregullimi i të dhënave sipas simbolit dhe kohës
        window_spec = Window.partitionBy("symbol").orderBy("timestamp")
        
        # Indikatorët teknikë
        df = df.withColumn("price_change", col("close") - col("open"))
        df = df.withColumn("price_change_pct", (col("close") - col("open")) / col("open") * 100)
        df = df.withColumn("high_low_diff", col("high") - col("low"))
        df = df.withColumn("volume_change", col("volume") - lag("volume", 1).over(window_spec))
        
        # Moving Averages
        df = df.withColumn("ma_5", avg("close").over(window_spec.rowsBetween(-4, 0)))
        df = df.withColumn("ma_10", avg("close").over(window_spec.rowsBetween(-9, 0)))
        df = df.withColumn("ma_20", avg("close").over(window_spec.rowsBetween(-19, 0)))
        df = df.withColumn("ma_50", avg("close").over(window_spec.rowsBetween(-49, 0)))
        
        # Exponential Moving Average
        df = df.withColumn("ema_12", 
                          sum(col("close") * pow(lit(0.8461), 
                          row_number().over(window_spec) - 1)).over(window_spec))
        df = df.withColumn("ema_26", 
                          sum(col("close") * pow(lit(0.9259), 
                          row_number().over(window_spec) - 1)).over(window_spec))
        
        # MACD
        df = df.withColumn("macd", col("ema_12") - col("ema_26"))
        df = df.withColumn("macd_signal", avg("macd").over(window_spec.rowsBetween(-8, 0)))
        df = df.withColumn("macd_hist", col("macd") - col("macd_signal"))
        
        # RSI (Relative Strength Index)
        df = df.withColumn("price_diff", col("close") - lag("close", 1).over(window_spec))
        df = df.withColumn("gain", when(col("price_diff") > 0, col("price_diff")).otherwise(0))
        df = df.withColumn("loss", when(col("price_diff") < 0, -col("price_diff")).otherwise(0))
        df = df.withColumn("avg_gain", avg("gain").over(window_spec.rowsBetween(-13, 0)))
        df = df.withColumn("avg_loss", avg("loss").over(window_spec.rowsBetween(-13, 0)))
        df = df.withColumn("rs", col("avg_gain") / (col("avg_loss") + 0.001))
        df = df.withColumn("rsi", lit(100) - (lit(100) / (lit(1) + col("rs"))))
        
        # Bollinger Bands
        df = df.withColumn("bb_middle", col("ma_20"))
        df = df.withColumn("bb_std", stddev("close").over(window_spec.rowsBetween(-19, 0)))
        df = df.withColumn("bb_upper", col("bb_middle") + (lit(2) * col("bb_std")))
        df = df.withColumn("bb_lower", col("bb_middle") - (lit(2) * col("bb_std")))
        df = df.withColumn("bb_width", (col("bb_upper") - col("bb_lower")) / col("bb_middle"))
        
        # Volatilitet
        df = df.withColumn("volatility_10", 
                          stddev("price_change_pct").over(window_spec.rowsBetween(-9, 0)))
        df = df.withColumn("volatility_20", 
                          stddev("price_change_pct").over(window_spec.rowsBetween(-19, 0)))
        
        # Volume indicators
        df = df.withColumn("volume_ma_20", avg("volume").over(window_spec.rowsBetween(-19, 0)))
        df = df.withColumn("volume_ratio", col("volume") / col("volume_ma_20"))
        
        # Target: Çmimi i ardhshëm (pas 1 ore = 12 intervale të 5 minutave)
        df = df.withColumn("target_price", lead("close", 12).over(window_spec))
        df = df.withColumn("target_return", 
                          (col("target_price") - col("close")) / col("close") * 100)
        
        # Heq radhët me vlera null
        df = df.na.drop()
        
        logger.info(f"U krijuan {len(df.columns)} features")
        return df
    
    def train_random_forest(self, train_df, test_df) -> Dict:
        """Trajnon Random Forest Regressor"""
        logger.info("Duke trajnuar Random Forest...")
        
        # Feature columns
        feature_cols = [
            "open", "high", "low", "close", "volume",
            "ma_5", "ma_10", "ma_20", "ma_50",
            "ema_12", "ema_26", "macd", "macd_signal", "macd_hist",
            "rsi", "bb_width", "volatility_10", "volatility_20",
            "volume_ratio", "price_change_pct"
        ]
        
        # Assemble features
        assembler = VectorAssembler(inputCols=feature_cols, outputCol="raw_features")
        scaler = StandardScaler(inputCol="raw_features", outputCol="features")
        
        # Random Forest
        rf = RandomForestRegressor(
            featuresCol="features",
            labelCol="target_return",
            numTrees=200,
            maxDepth=15,
            maxBins=64,
            minInstancesPerNode=5,
            subsamplingRate=0.8,
            featureSubsetStrategy="sqrt",
            seed=42
        )
        
        # Pipeline
        pipeline = Pipeline(stages=[assembler, scaler, rf])
        
        # Train
        model = pipeline.fit(train_df)
        
        # Evaluate
        predictions = model.transform(test_df)
        evaluator = RegressionEvaluator(
            labelCol="target_return",
            predictionCol="prediction",
            metricName="rmse"
        )
        
        rmse = evaluator.evaluate(predictions)
        mae_evaluator = RegressionEvaluator(
            labelCol="target_return",
            predictionCol="prediction",
            metricName="mae"
        )
        mae = mae_evaluator.evaluate(predictions)
        
        r2_evaluator = RegressionEvaluator(
            labelCol="target_return",
            predictionCol="prediction",
            metricName="r2"
        )
        r2 = r2_evaluator.evaluate(predictions)
        
        # Accuracy (përqindje brenda 5% gabimit)
        pred_pd = predictions.select("target_return", "prediction").toPandas()
        accuracy = np.mean(np.abs(pred_pd["target_return"] - pred_pd["prediction"]) < 5) * 100
        
        logger.info(f"Random Forest - RMSE: {rmse:.4f}, MAE: {mae:.4f}, R2: {r2:.4f}, Accuracy: {accuracy:.2f}%")
        
        # Save model
        model.write().overwrite().save("/opt/financial-analysis/models/random_forest")
        
        return {
            "model": model,
            "rmse": rmse,
            "mae": mae,
            "r2": r2,
            "accuracy": accuracy
        }
    
    def train_gradient_boosting(self, train_df, test_df) -> Dict:
        """Trajnon Gradient Boosting Trees"""
        logger.info("Duke trajnuar Gradient Boosting...")
        
        feature_cols = [
            "open", "high", "low", "close", "volume",
            "ma_5", "ma_10", "ma_20", "ma_50",
            "ema_12", "ema_26", "macd", "macd_signal", "macd_hist",
            "rsi", "bb_width", "volatility_10", "volatility_20",
            "volume_ratio", "price_change_pct"
        ]
        
        assembler = VectorAssembler(inputCols=feature_cols, outputCol="raw_features")
        scaler = StandardScaler(inputCol="raw_features", outputCol="features")
        
        gbt = GBTRegressor(
            featuresCol="features",
            labelCol="target_return",
            maxIter=150,
            maxDepth=8,
            stepSize=0.05,
            subsamplingRate=0.8,
            minInstancesPerNode=3,
            seed=42
        )
        
        pipeline = Pipeline(stages=[assembler, scaler, gbt])
        model = pipeline.fit(train_df)
        
        # Evaluate
        predictions = model.transform(test_df)
        
        rmse_evaluator = RegressionEvaluator(
            labelCol="target_return", predictionCol="prediction", metricName="rmse"
        )
        mae_evaluator = RegressionEvaluator(
            labelCol="target_return", predictionCol="prediction", metricName="mae"
        )
        r2_evaluator = RegressionEvaluator(
            labelCol="target_return", predictionCol="prediction", metricName="r2"
        )
        
        rmse = rmse_evaluator.evaluate(predictions)
        mae = mae_evaluator.evaluate(predictions)
        r2 = r2_evaluator.evaluate(predictions)
        
        pred_pd = predictions.select("target_return", "prediction").toPandas()
        accuracy = np.mean(np.abs(pred_pd["target_return"] - pred_pd["prediction"]) < 5) * 100
        
        logger.info(f"GBT - RMSE: {rmse:.4f}, MAE: {mae:.4f}, R2: {r2:.4f}, Accuracy: {accuracy:.2f}%")
        
        model.write().overwrite().save("/opt/financial-analysis/models/gradient_boosting")
        
        return {
            "model": model,
            "rmse": rmse,
            "mae": mae,
            "r2": r2,
            "accuracy": accuracy
        }
    
    def train_lstm(self, train_data: pd.DataFrame, test_data: pd.DataFrame) -> Dict:
        """Trajnon LSTM Neural Network për time series"""
        logger.info("Duke trajnuar LSTM Neural Network...")
        
        # Përgatit të dhënat për LSTM
        feature_cols = [
            "open", "high", "low", "close", "volume",
            "ma_5", "ma_10", "ma_20", "rsi", "macd"
        ]
        
        # Normalizimi
        from sklearn.preprocessing import StandardScaler
        scaler = StandardScaler()
        
        X_train = train_data[feature_cols].values
        y_train = train_data["target_return"].values
        X_test = test_data[feature_cols].values
        y_test = test_data["target_return"].values
        
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        
        # Reshape për LSTM [samples, timesteps, features]
        sequence_length = 60  # Përdor 60 intervale të kaluar
        
        def create_sequences(data, target, seq_length):
            X, y = [], []
            for i in range(len(data) - seq_length):
                X.append(data[i:i+seq_length])
                y.append(target[i+seq_length])
            return np.array(X), np.array(y)
        
        X_train_seq, y_train_seq = create_sequences(X_train_scaled, y_train, sequence_length)
        X_test_seq, y_test_seq = create_sequences(X_test_scaled, y_test, sequence_length)
        
        # Krijo modelin LSTM
        model = keras.Sequential([
            layers.LSTM(128, return_sequences=True, input_shape=(sequence_length, len(feature_cols))),
            layers.Dropout(0.3),
            layers.LSTM(64, return_sequences=True),
            layers.Dropout(0.3),
            layers.LSTM(32),
            layers.Dropout(0.2),
            layers.Dense(64, activation='relu'),
            layers.Dropout(0.2),
            layers.Dense(32, activation='relu'),
            layers.Dense(1)
        ])
        
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae']
        )
        
        # Early stopping
        early_stop = keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=15,
            restore_best_weights=True
        )
        
        # Trajnoni modelin
        history = model.fit(
            X_train_seq, y_train_seq,
            validation_split=0.2,
            epochs=100,
            batch_size=256,
            callbacks=[early_stop],
            verbose=0
        )
        
        # Evaluate
        predictions = model.predict(X_test_seq)
        
        mape = mean_absolute_percentage_error(y_test_seq, predictions)
        r2 = r2_score(y_test_seq, predictions)
        mae = np.mean(np.abs(y_test_seq - predictions.flatten()))
        accuracy = np.mean(np.abs(y_test_seq - predictions.flatten()) < 5) * 100
        
        logger.info(f"LSTM - MAPE: {mape:.4f}, MAE: {mae:.4f}, R2: {r2:.4f}, Accuracy: {accuracy:.2f}%")
        
        # Save model
        model.save("/opt/financial-analysis/models/lstm_model.h5")
        
        with open("/opt/financial-analysis/models/lstm_scaler.pkl", "wb") as f:
            pickle.dump(scaler, f)
        
        return {
            "model": model,
            "scaler": scaler,
            "mape": mape,
            "mae": mae,
            "r2": r2,
            "accuracy": accuracy
        }
    
    def perform_clustering(self, df) -> Dict:
        """K-Means Clustering për grupimin e aseteve"""
        logger.info("Duke kryer K-Means Clustering...")
        
        # Features për clustering
        feature_cols = [
            "volatility_20", "volume_ratio", "rsi",
            "price_change_pct", "bb_width"
        ]
        
        assembler = VectorAssembler(inputCols=feature_cols, outputCol="raw_features")
        scaler = StandardScaler(inputCol="raw_features", outputCol="features")
        
        # K-Means me 5 cluster
        kmeans = KMeans(k=5, seed=42, featuresCol="features", predictionCol="cluster")
        
        pipeline = Pipeline(stages=[assembler, scaler, kmeans])
        model = pipeline.fit(df)
        
        clustered = model.transform(df)
        
        # Analizo clusters
        cluster_stats = clustered.groupBy("cluster").agg(
            count("*").alias("count"),
            avg("volatility_20").alias("avg_volatility"),
            avg("target_return").alias("avg_return"),
            avg("volume_ratio").alias("avg_volume_ratio")
        ).toPandas()
        
        logger.info("Statistikat e Cluster:")
        logger.info(f"\n{cluster_stats}")
        
        # Save model
        model.write().overwrite().save("/opt/financial-analysis/models/kmeans_clustering")
        
        return {
            "model": model,
            "cluster_stats": cluster_stats,
            "clustered_data": clustered
        }
    
    def detect_anomalies(self, df_pd: pd.DataFrame) -> pd.DataFrame:
        """Isolation Forest për zbulimin e anomalive"""
        logger.info("Duke zbuluar anomalitë...")
        
        feature_cols = [
            "close", "volume", "volatility_20", "rsi", "price_change_pct"
        ]
        
        X = df_pd[feature_cols].values
        
        iso_forest = IsolationForest(
            contamination=0.05,
            random_state=42,
            n_estimators=200,
            max_samples=1000
        )
        
        df_pd['anomaly'] = iso_forest.fit_predict(X)
        df_pd['anomaly_score'] = iso_forest.score_samples(X)
        
        anomaly_count = (df_pd['anomaly'] == -1).sum()
        logger.info(f"U zbuluan {anomaly_count} anomali ({anomaly_count/len(df_pd)*100:.2f}%)")
        
        return df_pd
    
    def ensemble_predict(self, data_df) -> pd.DataFrame:
        """Parashikon duke përdorur ensemble të modeleve"""
        logger.info("Duke bërë parashikime me ensemble...")
        
        # Load models
        rf_model = Pipeline.load("/opt/financial-analysis/models/random_forest")
        gbt_model = Pipeline.load("/opt/financial-analysis/models/gradient_boosting")
        
        # Predictions
        rf_pred = rf_model.transform(data_df)
        gbt_pred = gbt_model.transform(data_df)
        
        # Ensemble: Mesatarja me peshë
        rf_weight = self.model_performance.get('random_forest', {}).get('accuracy', 50) / 100
        gbt_weight = self.model_performance.get('gradient_boosting', {}).get('accuracy', 50) / 100
        
        total_weight = rf_weight + gbt_weight
        
        ensemble_df = rf_pred.withColumn(
            "ensemble_prediction",
            (col("prediction") * lit(rf_weight) + 
             gbt_pred.select("prediction").alias("gbt_pred") * lit(gbt_weight)) / lit(total_weight)
        )
        
        return ensemble_df
    
    def generate_recommendations(self, predictions_df) -> pd.DataFrame:
        """Gjeneron rekomandime investimi bazuar në parashikime"""
        logger.info("Duke gjeneruar rekomandime investimi...")
        
        pred_pd = predictions_df.toPandas()
        
        # Scoring sistemi
        pred_pd['invest_score'] = 0
        
        # Fatorët pozitivë
        pred_pd.loc[pred_pd['ensemble_prediction'] > 2, 'invest_score'] += 3  # Parashikim pozitiv i fortë
        pred_pd.loc[pred_pd['ensemble_prediction'] > 1, 'invest_score'] += 2
        pred_pd.loc[pred_pd['ensemble_prediction'] > 0, 'invest_score'] += 1
        
        pred_pd.loc[pred_pd['rsi'] < 30, 'invest_score'] += 2  # Oversold
        pred_pd.loc[pred_pd['rsi'] < 40, 'invest_score'] += 1
        
        pred_pd.loc[pred_pd['close'] < pred_pd['bb_lower'], 'invest_score'] += 2  # Nën Bollinger Band
        
        pred_pd.loc[pred_pd['macd_hist'] > 0, 'invest_score'] += 1  # MACD pozitiv
        
        # Fatorët negativë
        pred_pd.loc[pred_pd['ensemble_prediction'] < -1, 'invest_score'] -= 3
        pred_pd.loc[pred_pd['rsi'] > 70, 'invest_score'] -= 2  # Overbought
        pred_pd.loc[pred_pd['close'] > pred_pd['bb_upper'], 'invest_score'] -= 2
        pred_pd.loc[pred_pd['volatility_20'] > 10, 'invest_score'] -= 1  # Volatilitet i lartë
        
        # Rekomandimi final
        pred_pd['recommendation'] = 'HOLD'
        pred_pd.loc[pred_pd['invest_score'] >= 5, 'recommendation'] = 'STRONG BUY'
        pred_pd.loc[(pred_pd['invest_score'] >= 3) & (pred_pd['invest_score'] < 5), 'recommendation'] = 'BUY'
        pred_pd.loc[pred_pd['invest_score'] <= -3, 'recommendation'] = 'SELL'
        pred_pd.loc[pred_pd['invest_score'] <= -5, 'recommendation'] = 'STRONG SELL'
        
        logger.info(f"Rekomandime të gjeneruara: {pred_pd['recommendation'].value_counts().to_dict()}")
        
        return pred_pd
    
    def train_all_models(self, data_path: str):
        """Trajnon të gjitha modelet"""
        logger.info("="*60)
        logger.info("Fillimi i Trajnimit të Modeleve")
        logger.info("="*60)
        
        # Load data
        df = self.spark.read.parquet(data_path)
        logger.info(f"U ngarkuan {df.count()} rekorde")
        
        # Prepare features
        df = self.prepare_features(df)
        
        # Split data
        train_df, test_df = df.randomSplit([0.8, 0.2], seed=42)
        logger.info(f"Training: {train_df.count()}, Testing: {test_df.count()}")
        
        # Train models
        self.model_performance['random_forest'] = self.train_random_forest(train_df, test_df)
        self.model_performance['gradient_boosting'] = self.train_gradient_boosting(train_df, test_df)
        
        # LSTM (convert to pandas for TensorFlow)
        train_pd = train_df.sample(fraction=0.1).toPandas()  # Sample për shpejtësi
        test_pd = test_df.sample(fraction=0.1).toPandas()
        self.model_performance['lstm'] = self.train_lstm(train_pd, test_pd)
        
        # Clustering
        clustering_result = self.perform_clustering(df)
        self.model_performance['clustering'] = clustering_result
        
        # Save performance metrics
        with open("/opt/financial-analysis/models/performance_metrics.json", "w") as f:
            # Konverto për JSON serialization
            metrics = {}
            for model_name, perf in self.model_performance.items():
                if model_name != 'clustering':
                    metrics[model_name] = {k: float(v) if isinstance(v, (np.floating, np.integer)) else v 
                                          for k, v in perf.items() if k != 'model' and k != 'scaler'}
            json.dump(metrics, f, indent=2)
        
        logger.info("="*60)
        logger.info("Trajnimi i modeleve u përfundua me sukses!")
        logger.info("="*60)
        
        return self.model_performance


if __name__ == "__main__":
    predictor = MLPredictor()
    
    try:
        # Trajnoni modelet me të dhënat e mbledhura
        predictor.train_all_models("/opt/financial-analysis/data/raw/*.parquet")
    except Exception as e:
        logger.error(f"Gabim: {e}")
        raise
    finally:
        predictor.spark.stop()
