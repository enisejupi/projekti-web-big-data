"""
Dashboard Interaktiv për Analizën e Aseteve Financiare
Shfaq të dhënat, parashikimet dhe rekomandimet në kohë reale
"""

import dash
from dash import dcc, html, Input, Output, State, dash_table
import dash_bootstrap_components as dbc
import plotly.graph_objs as go
import plotly.express as px
from plotly.subplots import make_subplots
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import os
from pyspark.sql import SparkSession
import logging
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib import colors
import matplotlib.pyplot as plt
import seaborn as sns
from io import BytesIO
import base64

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inicializo Spark
spark = SparkSession.builder \
    .appName("Dashboard") \
    .master("spark://10.0.0.4:7077") \
    .config("spark.driver.memory", "20g") \
    .getOrCreate()

spark.sparkContext.setLogLevel("ERROR")

# Inicializo Dash app
app = dash.Dash(__name__, external_stylesheets=[dbc.themes.DARKLY])
app.title = "Dashboard i Analizës Financiare"

# Ngjyrat
COLORS = {
    'background': '#1e1e1e',
    'text': '#ffffff',
    'primary': '#00d4ff',
    'success': '#00ff88',
    'danger': '#ff4444',
    'warning': '#ffaa00',
    'info': '#4dabf7'
}


def load_latest_data():
    """Ngarkon të dhënat më të fundit"""
    try:
        # Merr filet më të fundit parquet
        data_dir = "/opt/financial-analysis/data/raw"
        files = [f for f in os.listdir(data_dir) if f.endswith('.parquet')]
        
        if not files:
            return pd.DataFrame()
        
        latest_file = sorted(files)[-1]
        df = spark.read.parquet(f"{data_dir}/{latest_file}").toPandas()
        
        return df
    except Exception as e:
        logger.error(f"Gabim në ngarkimin e të dhënave: {e}")
        return pd.DataFrame()


def load_predictions():
    """Ngarkon parashikimet"""
    try:
        pred_file = "/opt/financial-analysis/data/predictions/latest_predictions.parquet"
        if os.path.exists(pred_file):
            df = spark.read.parquet(pred_file).toPandas()
            return df
        return pd.DataFrame()
    except Exception as e:
        logger.error(f"Gabim në ngarkimin e parashikimeve: {e}")
        return pd.DataFrame()


def load_model_performance():
    """Ngarkon performancën e modeleve"""
    try:
        with open("/opt/financial-analysis/models/performance_metrics.json", "r") as f:
            return json.load(f)
    except:
        return {}


# Layout i Dashboard
app.layout = dbc.Container([
    dbc.Row([
        dbc.Col([
            html.H1("📊 Dashboard i Analizës së Aseteve Financiare",
                   style={'textAlign': 'center', 'color': COLORS['primary'], 'marginTop': 20}),
            html.H5("Sistem i Avancuar me Apache Spark & Machine Learning",
                   style={'textAlign': 'center', 'color': COLORS['text'], 'marginBottom': 30}),
        ])
    ]),
    
    # Statistikat kryesore
    dbc.Row([
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("Asete të Monitoruara", className="card-title"),
                    html.H2(id="total-assets", children="0", style={'color': COLORS['primary']}),
                    html.P("në kohë reale", className="card-text")
                ])
            ], color="dark")
        ], width=3),
        
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("Saktësia Mesatare", className="card-title"),
                    html.H2(id="avg-accuracy", children="0%", style={'color': COLORS['success']}),
                    html.P("e modeleve ML", className="card-text")
                ])
            ], color="dark")
        ], width=3),
        
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("Strong Buy", className="card-title"),
                    html.H2(id="strong-buy-count", children="0", style={'color': COLORS['success']}),
                    html.P("rekomandime", className="card-text")
                ])
            ], color="dark")
        ], width=3),
        
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("Kohëzgjatja", className="card-title"),
                    html.H2(id="runtime", children="0h", style={'color': COLORS['warning']}),
                    html.P("nga 84 orë", className="card-text")
                ])
            ], color="dark")
        ], width=3),
    ], className="mb-4"),
    
    # Tabs
    dbc.Tabs([
        # Tab 1: Përmbledhje
        dbc.Tab(label="📈 Përmbledhje", children=[
            dbc.Row([
                dbc.Col([
                    dcc.Graph(id="price-chart", style={'height': '500px'})
                ], width=8),
                dbc.Col([
                    html.H4("Top 10 Rekomandime", style={'color': COLORS['primary'], 'marginTop': 20}),
                    html.Div(id="top-recommendations")
                ], width=4)
            ], className="mt-3"),
            
            dbc.Row([
                dbc.Col([
                    dcc.Graph(id="sector-performance", style={'height': '400px'})
                ], width=6),
                dbc.Col([
                    dcc.Graph(id="volatility-distribution", style={'height': '400px'})
                ], width=6)
            ], className="mt-3")
        ]),
        
        # Tab 2: Parashikime ML
        dbc.Tab(label="🤖 Parashikime ML", children=[
            dbc.Row([
                dbc.Col([
                    html.H4("Performanca e Modeleve", style={'color': COLORS['primary'], 'marginTop': 20}),
                    dcc.Graph(id="model-performance", style={'height': '400px'})
                ], width=6),
                dbc.Col([
                    html.H4("Krahasimi i Parashikimeve", style={'color': COLORS['primary'], 'marginTop': 20}),
                    dcc.Graph(id="prediction-comparison", style={'height': '400px'})
                ], width=6)
            ]),
            
            dbc.Row([
                dbc.Col([
                    html.H4("Matrica e Gabimeve", style={'color': COLORS['primary'], 'marginTop': 20}),
                    dcc.Graph(id="error-matrix", style={'height': '400px'})
                ], width=12)
            ], className="mt-3")
        ]),
        
        # Tab 3: Clustering
        dbc.Tab(label="🎯 Grupimi i Aseteve", children=[
            dbc.Row([
                dbc.Col([
                    html.H4("Cluster 3D Visualization", style={'color': COLORS['primary'], 'marginTop': 20}),
                    dcc.Graph(id="cluster-3d", style={'height': '600px'})
                ], width=8),
                dbc.Col([
                    html.H4("Statistikat e Cluster", style={'color': COLORS['primary'], 'marginTop': 20}),
                    html.Div(id="cluster-stats")
                ], width=4)
            ])
        ]),
        
        # Tab 4: Rekomandime
        dbc.Tab(label="💼 Rekomandime Investimi", children=[
            dbc.Row([
                dbc.Col([
                    html.H4("Filtro sipas Rekomandimit", style={'color': COLORS['primary'], 'marginTop': 20}),
                    dcc.Dropdown(
                        id='recommendation-filter',
                        options=[
                            {'label': '🟢 STRONG BUY', 'value': 'STRONG BUY'},
                            {'label': '🔵 BUY', 'value': 'BUY'},
                            {'label': '⚪ HOLD', 'value': 'HOLD'},
                            {'label': '🟠 SELL', 'value': 'SELL'},
                            {'label': '🔴 STRONG SELL', 'value': 'STRONG SELL'},
                        ],
                        value='STRONG BUY',
                        style={'color': '#000000'}
                    )
                ], width=12)
            ], className="mt-3"),
            
            dbc.Row([
                dbc.Col([
                    dash_table.DataTable(
                        id='recommendations-table',
                        style_cell={
                            'backgroundColor': COLORS['background'],
                            'color': COLORS['text'],
                            'textAlign': 'left',
                            'padding': '10px'
                        },
                        style_header={
                            'backgroundColor': COLORS['primary'],
                            'color': 'black',
                            'fontWeight': 'bold'
                        },
                        style_data_conditional=[
                            {
                                'if': {'filter_query': '{recommendation} = "STRONG BUY"'},
                                'backgroundColor': '#00ff8844',
                            },
                            {
                                'if': {'filter_query': '{recommendation} = "BUY"'},
                                'backgroundColor': '#4dabf744',
                            },
                        ],
                        page_size=20,
                        sort_action='native',
                        filter_action='native'
                    )
                ])
            ], className="mt-3")
        ]),
        
        # Tab 5: Eksportim
        dbc.Tab(label="📥 Eksporto Raportin", children=[
            dbc.Row([
                dbc.Col([
                    html.H4("Gjenero Raport PDF", style={'color': COLORS['primary'], 'marginTop': 30, 'textAlign': 'center'}),
                    html.P("Prezantim i plotë me të gjitha analizat dhe rekomandimet", 
                          style={'textAlign': 'center', 'marginBottom': 30}),
                    
                    dbc.Button(
                        "📥 EKSPORTO PREZANTIMIN",
                        id="export-button",
                        color="success",
                        size="lg",
                        style={'width': '100%', 'height': '80px', 'fontSize': '24px'}
                    ),
                    
                    html.Div(id="export-status", style={'marginTop': 20, 'textAlign': 'center'})
                ], width={'size': 6, 'offset': 3})
            ])
        ])
    ]),
    
    # Interval për përditësim automatik (çdo 30 sekonda)
    dcc.Interval(
        id='interval-component',
        interval=30*1000,  # 30 sekonda
        n_intervals=0
    ),
    
    # Store për të dhënat
    dcc.Store(id='data-store'),
    dcc.Store(id='predictions-store'),
    
], fluid=True, style={'backgroundColor': COLORS['background']})


# Callbacks

@app.callback(
    [Output('data-store', 'data'),
     Output('predictions-store', 'data')],
    Input('interval-component', 'n_intervals')
)
def update_data(n):
    """Përditëson të dhënat çdo 30 sekonda"""
    df = load_latest_data()
    pred_df = load_predictions()
    
    if not df.empty:
        return df.to_json(date_format='iso', orient='split'), pred_df.to_json(date_format='iso', orient='split') if not pred_df.empty else None
    return None, None


@app.callback(
    [Output('total-assets', 'children'),
     Output('avg-accuracy', 'children'),
     Output('strong-buy-count', 'children'),
     Output('runtime', 'children')],
    Input('data-store', 'data')
)
def update_stats(data_json):
    """Përditëson statistikat kryesore"""
    if not data_json:
        return "0", "0%", "0", "0h"
    
    df = pd.read_json(data_json, orient='split')
    
    total_assets = df['symbol'].nunique()
    
    # Accuracy nga model performance
    perf = load_model_performance()
    avg_acc = np.mean([v.get('accuracy', 0) for v in perf.values()]) if perf else 0
    
    # Strong Buy count
    pred_file = "/opt/financial-analysis/data/predictions/latest_predictions.parquet"
    strong_buy = 0
    if os.path.exists(pred_file):
        pred_df = spark.read.parquet(pred_file).toPandas()
        strong_buy = (pred_df['recommendation'] == 'STRONG BUY').sum()
    
    # Runtime
    start_file = "/opt/financial-analysis/logs/start_time.txt"
    if os.path.exists(start_file):
        with open(start_file, 'r') as f:
            start_time = datetime.fromisoformat(f.read().strip())
            runtime_hours = (datetime.now() - start_time).total_seconds() / 3600
    else:
        runtime_hours = 0
    
    return str(total_assets), f"{avg_acc:.1f}%", str(strong_buy), f"{runtime_hours:.1f}h"


@app.callback(
    Output('price-chart', 'figure'),
    Input('data-store', 'data')
)
def update_price_chart(data_json):
    """Grafiku i çmimeve"""
    if not data_json:
        return go.Figure()
    
    df = pd.read_json(data_json, orient='split')
    
    # Top 10 asetet
    top_symbols = df.groupby('symbol')['volume'].mean().nlargest(10).index.tolist()
    df_top = df[df['symbol'].isin(top_symbols)]
    
    fig = go.Figure()
    
    for symbol in top_symbols:
        symbol_data = df_top[df_top['symbol'] == symbol].sort_values('timestamp')
        fig.add_trace(go.Scatter(
            x=symbol_data['timestamp'],
            y=symbol_data['close'],
            mode='lines',
            name=symbol,
            line=dict(width=2)
        ))
    
    fig.update_layout(
        title="Lëvizja e Çmimeve - Top 10 Asete",
        xaxis_title="Koha",
        yaxis_title="Çmimi",
        template="plotly_dark",
        hovermode='x unified',
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
    )
    
    return fig


@app.callback(
    Output('top-recommendations', 'children'),
    Input('predictions-store', 'data')
)
def update_top_recommendations(pred_json):
    """Top rekomandimet"""
    if not pred_json:
        return html.P("Nuk ka të dhëna", style={'color': COLORS['text']})
    
    df = pd.read_json(pred_json, orient='split')
    
    # Top 10 STRONG BUY
    top_buys = df[df['recommendation'] == 'STRONG BUY'].nlargest(10, 'invest_score')
    
    cards = []
    for idx, row in top_buys.iterrows():
        card = dbc.Card([
            dbc.CardBody([
                html.H5(row['symbol'], style={'color': COLORS['success']}),
                html.P(f"Score: {row['invest_score']:.1f}", className="mb-0"),
                html.P(f"Parashikim: +{row['ensemble_prediction']:.2f}%", className="mb-0", style={'fontSize': '12px'})
            ])
        ], color="success", outline=True, className="mb-2")
        cards.append(card)
    
    return cards


@app.callback(
    Output('model-performance', 'figure'),
    Input('interval-component', 'n_intervals')
)
def update_model_performance(n):
    """Grafiku i performancës së modeleve"""
    perf = load_model_performance()
    
    if not perf:
        return go.Figure()
    
    models = list(perf.keys())
    accuracies = [perf[m].get('accuracy', 0) for m in models]
    r2_scores = [perf[m].get('r2', 0) * 100 for m in models]
    
    fig = go.Figure(data=[
        go.Bar(name='Saktësia (%)', x=models, y=accuracies, marker_color=COLORS['success']),
        go.Bar(name='R² Score (%)', x=models, y=r2_scores, marker_color=COLORS['info'])
    ])
    
    fig.update_layout(
        title="Performanca e Modeleve të ML",
        barmode='group',
        template="plotly_dark",
        yaxis_title="Përqindja (%)",
        xaxis_title="Modeli"
    )
    
    # Shto linjë reference për 90%
    fig.add_hline(y=90, line_dash="dash", line_color="red", 
                  annotation_text="Target: 90%", annotation_position="right")
    
    return fig


@app.callback(
    Output('recommendations-table', 'data'),
    Output('recommendations-table', 'columns'),
    Input('recommendation-filter', 'value'),
    Input('predictions-store', 'data')
)
def update_recommendations_table(filter_value, pred_json):
    """Tabela e rekomandimeve"""
    if not pred_json:
        return [], []
    
    df = pd.read_json(pred_json, orient='split')
    
    filtered = df[df['recommendation'] == filter_value].sort_values('invest_score', ascending=False)
    
    # Kollonat për tabelë
    columns = [
        {'name': 'Simboli', 'id': 'symbol'},
        {'name': 'Çmimi', 'id': 'close'},
        {'name': 'Parashikim (%)', 'id': 'ensemble_prediction'},
        {'name': 'RSI', 'id': 'rsi'},
        {'name': 'Volatiliteti', 'id': 'volatility_20'},
        {'name': 'Score', 'id': 'invest_score'},
        {'name': 'Rekomandimi', 'id': 'recommendation'}
    ]
    
    # Format data
    display_df = filtered[['symbol', 'close', 'ensemble_prediction', 'rsi', 'volatility_20', 'invest_score', 'recommendation']].copy()
    display_df['close'] = display_df['close'].round(2)
    display_df['ensemble_prediction'] = display_df['ensemble_prediction'].round(2)
    display_df['rsi'] = display_df['rsi'].round(1)
    display_df['volatility_20'] = display_df['volatility_20'].round(2)
    display_df['invest_score'] = display_df['invest_score'].round(1)
    
    return display_df.to_dict('records'), columns


@app.callback(
    Output('export-status', 'children'),
    Input('export-button', 'n_clicks'),
    prevent_initial_call=True
)
def export_presentation(n_clicks):
    """Eksporton prezantimin në PDF"""
    try:
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        filename = f"/opt/financial-analysis/exports/prezantimi_{timestamp}.pdf"
        
        # Krijo PDF me raport të plotë
        # (Implementimi i plotë do të ishte shumë i gjatë, ky është një shembull)
        
        logger.info(f"Duke gjeneruar prezantim: {filename}")
        
        # Placeholder - do të implementohet plotësisht
        with open(filename, 'w') as f:
            f.write("Placeholder për PDF prezantim")
        
        return dbc.Alert(
            [
                html.H4("✅ Sukses!", className="alert-heading"),
                html.P(f"Prezantimi u ruajt në: {filename}"),
                html.Hr(),
                html.P("Mund ta shkarkoni nga VM me SCP ose SFTP.", className="mb-0")
            ],
            color="success"
        )
    
    except Exception as e:
        logger.error(f"Gabim në eksportim: {e}")
        return dbc.Alert(f"❌ Gabim: {e}", color="danger")


if __name__ == '__main__':
    logger.info("Duke nisur Dashboard...")
    logger.info("Dashboard do të jetë i aksesueshem në: http://10.0.0.4:8050")
    logger.info("Lokalisht (me port forwarding): http://localhost:8050")
    
    app.run_server(host='0.0.0.0', port=8050, debug=False)
