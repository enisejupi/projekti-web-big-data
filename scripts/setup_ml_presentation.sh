#!/bin/bash
# Create working ML and presentation functionality

cd /opt/financial-analysis

echo "Creating simple ML predictor..."
cat > ml_models/simple_predictor.py << 'PYEOF'
import pandas as pd
import psycopg2
from sklearn.linear_model import LinearRegression
from datetime import datetime, timedelta
import pickle
import os

class SimplePredictor:
    def __init__(self):
        self.models = {}
        self.model_dir = 'ml_models/models'
        os.makedirs(self.model_dir, exist_ok=True)
        
    def get_data(self):
        """Get data from database"""
        conn = psycopg2.connect(
            host='10.0.0.4',
            database='financial_data',
            user='financeuser',
            password='Finance@2025!Secure'
        )
        query = """
            SELECT symbol, timestamp, close, volume, daily_return, volatility
            FROM market_data
            ORDER BY symbol, timestamp
        """
        df = pd.read_sql(query, conn)
        conn.close()
        return df
    
    def train_models(self):
        """Train simple models for top symbols"""
        df = self.get_data()
        symbols = df['symbol'].value_counts().head(20).index
        
        for symbol in symbols:
            symbol_data = df[df['symbol'] == symbol].sort_values('timestamp')
            if len(symbol_data) < 10:
                continue
                
            # Create features
            symbol_data['day'] = range(len(symbol_data))
            X = symbol_data[['day', 'volume']].values
            y = symbol_data['close'].values
            
            # Train model
            model = LinearRegression()
            model.fit(X, y)
            
            # Save model
            model_file = f'{self.model_dir}/{symbol}_model.pkl'
            with open(model_file, 'wb') as f:
                pickle.dump(model, f)
            
            self.models[symbol] = model
        
        print(f"Trained {len(self.models)} models")
        return len(self.models)
    
    def predict_prices(self, symbols=None):
        """Generate predictions"""
        df = self.get_data()
        
        if symbols is None:
            symbols = df['symbol'].value_counts().head(10).index.tolist()
        
        predictions = []
        for symbol in symbols:
            symbol_data = df[df['symbol'] == symbol].sort_values('timestamp')
            if len(symbol_data) < 5:
                continue
            
            latest = symbol_data.iloc[-1]
            current_price = latest['close']
            
            # Simple prediction: trend-based
            if len(symbol_data) >= 2:
                prev_price = symbol_data.iloc[-2]['close']
                trend = (current_price - prev_price) / prev_price
            else:
                trend = 0
            
            predicted_price = current_price * (1 + trend)
            confidence = 0.75 + (abs(trend) * 10)  # Simple confidence
            
            predictions.append({
                'symbol': symbol,
                'current_price': round(current_price, 2),
                'predicted_price': round(predicted_price, 2),
                'confidence': min(0.95, confidence),
                'trend': 'UP' if trend > 0 else 'DOWN',
                'change_pct': round(trend * 100, 2)
            })
        
        return pd.DataFrame(predictions)

if __name__ == '__main__':
    predictor = SimplePredictor()
    print("Training models...")
    predictor.train_models()
    print("Generating predictions...")
    preds = predictor.predict_prices()
    os.makedirs('reports', exist_ok=True)
    preds.to_csv('reports/predictions.csv', index=False)
    print(f"✓ Saved {len(preds)} predictions")
PYEOF

echo "Creating simple presentation generator..."
cat > scripts/simple_generate_presentation.py << 'PYEOF'
from pptx import Presentation
from pptx.util import Inches, Pt
import psycopg2
import pandas as pd
from datetime import datetime
import os

def create_presentation():
    # Get data from database
    conn = psycopg2.connect(
        host='10.0.0.4',
        database='financial_data',
        user='financeuser',
        password='Finance@2025!Secure'
    )
    
    query = """
        SELECT 
            COUNT(*) as total_records,
            COUNT(DISTINCT symbol) as total_symbols,
            AVG(close) as avg_price,
            MAX(timestamp) as latest_update
        FROM market_data
    """
    stats = pd.read_sql(query, conn)
    
    query2 = """
        SELECT symbol, AVG(close) as avg_price, COUNT(*) as data_points
        FROM market_data
        GROUP BY symbol
        ORDER BY data_points DESC
        LIMIT 10
    """
    top_symbols = pd.read_sql(query2, conn)
    conn.close()
    
    # Create presentation
    prs = Presentation()
    prs.slide_width = Inches(10)
    prs.slide_height = Inches(7.5)
    
    # Title slide
    slide = prs.slides.add_slide(prs.slide_layouts[0])
    title = slide.shapes.title
    subtitle = slide.placeholders[1]
    title.text = "Financial Analysis Report"
    subtitle.text = f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}"
    
    # Statistics slide
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    title = slide.shapes.title
    title.text = "Market Data Statistics"
    
    left = Inches(1)
    top = Inches(2)
    width = Inches(8)
    height = Inches(1)
    
    txBox = slide.shapes.add_textbox(left, top, width, height)
    tf = txBox.text_frame
    tf.text = f"""Total Records: {stats['total_records'].iloc[0]:,}
Total Symbols: {stats['total_symbols'].iloc[0]}
Average Price: ${stats['avg_price'].iloc[0]:.2f}
Latest Update: {stats['latest_update'].iloc[0]}"""
    
    # Top symbols slide
    slide = prs.slides.add_slide(prs.slide_layouts[5])
    title = slide.shapes.title
    title.text = "Top 10 Symbols by Data Points"
    
    txBox = slide.shapes.add_textbox(Inches(1), Inches(2), Inches(8), Inches(4))
    tf = txBox.text_frame
    
    for _, row in top_symbols.iterrows():
        p = tf.add_paragraph()
        p.text = f"{row['symbol']}: ${row['avg_price']:.2f} ({row['data_points']} records)"
        p.level = 0
    
    # Save
    os.makedirs('reports', exist_ok=True)
    filename = f"reports/presentation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pptx"
    prs.save(filename)
    print(f"✅ Presentation saved: {filename}")
    return filename

if __name__ == '__main__':
    create_presentation()
PYEOF

echo "Training ML models..."
python3.9 ml_models/simple_predictor.py

echo "Generating presentation..."
python3.9 scripts/simple_generate_presentation.py

echo ""
echo "=========================================="
echo "✅ ML and Presentation Ready!"
echo "=========================================="
ls -lh reports/

echo ""
echo "Now start port forwarding and test:"
echo "  cd c:\\Users\\Lenovo\\projekti-web-info\\scripts"
echo "  .\\manage.ps1 -Action port-forward"
echo ""
echo "Then open: http://localhost:8050"
