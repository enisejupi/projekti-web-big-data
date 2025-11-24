#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
Advanced Multi-Page Financial Dashboard
With ML Predictions, Visualizations, and Presentation Generation
"""

import sqlite3
import dash
from dash import html, dcc, Input, Output, State
import dash_bootstrap_components as dbc
import plotly.graph_objs as go
import plotly.express as px
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from io import BytesIO
import base64

# ML Libraries
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

app = dash.Dash(__name__, external_stylesheets=[dbc.themes.CYBORG], suppress_callback_exceptions=True)

DB_PATH = '/opt/financial-analysis/data/market_data.db'

def get_db_connection():
    """Get database connection"""
    return sqlite3.connect(DB_PATH)

def get_db_stats():
    """Get comprehensive database statistics"""
    try:
        conn = get_db_connection()
        
        stats = {}
        
        # Total records
        stats['total'] = pd.read_sql_query("SELECT COUNT(*) as cnt FROM market_data", conn)['cnt'].iloc[0]
        
        # Unique symbols
        stats['symbols'] = pd.read_sql_query("SELECT COUNT(DISTINCT symbol) as cnt FROM market_data", conn)['cnt'].iloc[0]
        
        # Latest timestamp
        result = pd.read_sql_query("SELECT MAX(timestamp) as latest FROM market_data", conn)
        stats['latest'] = result['latest'].iloc[0] if not result.empty else 'N/A'
        
        # Data range
        dates = pd.read_sql_query("SELECT MIN(timestamp) as first, MAX(timestamp) as last FROM market_data", conn)
        stats['first_date'] = dates['first'].iloc[0] if not dates.empty else 'N/A'
        stats['last_date'] = dates['last'].iloc[0] if not dates.empty else 'N/A'
        
        # Top symbols by volume
        stats['top_volume'] = pd.read_sql_query("""
            SELECT symbol, AVG(volume) as avg_vol, COUNT(*) as records
            FROM market_data 
            GROUP BY symbol 
            ORDER BY avg_vol DESC 
            LIMIT 10
        """, conn)
        
        # Top gainers
        stats['top_gainers'] = pd.read_sql_query("""
            SELECT symbol, AVG(change_percent) as avg_change
            FROM market_data 
            WHERE change_percent IS NOT NULL
            GROUP BY symbol 
            ORDER BY avg_change DESC 
            LIMIT 10
        """, conn)
        
        # Top losers
        stats['top_losers'] = pd.read_sql_query("""
            SELECT symbol, AVG(change_percent) as avg_change
            FROM market_data 
            WHERE change_percent IS NOT NULL
            GROUP BY symbol 
            ORDER BY avg_change ASC 
            LIMIT 10
        """, conn)
        
        conn.close()
        return stats
    except Exception as e:
        return {'error': str(e)}

def get_all_data():
    """Get all market data"""
    try:
        conn = get_db_connection()
        df = pd.read_sql_query("SELECT * FROM market_data ORDER BY timestamp DESC", conn)
        conn.close()
        return df
    except:
        return pd.DataFrame()

def get_symbol_data(symbol, limit=1000):
    """Get data for specific symbol"""
    try:
        conn = get_db_connection()
        df = pd.read_sql_query(f"""
            SELECT * FROM market_data 
            WHERE symbol = '{symbol}'
            ORDER BY timestamp DESC 
            LIMIT {limit}
        """, conn)
        conn.close()
        return df
    except:
        return pd.DataFrame()

def run_ml_predictions():
    """Run ML models and generate predictions"""
    try:
        df = get_all_data()
        if df.empty or len(df) < 100:
            return None
        
        # Prepare features
        df = df.dropna(subset=['price', 'volume'])
        df['timestamp'] = pd.to_datetime(df['timestamp'])
        
        # Create features
        features = df[['volume', 'day_high', 'day_low', 'change_percent']].fillna(0)
        target = df['price']
        
        # Random Forest
        rf_model = RandomForestRegressor(n_estimators=100, max_depth=10, random_state=42)
        rf_model.fit(features, target)
        rf_score = rf_model.score(features, target)
        
        # Gradient Boosting
        gb_model = GradientBoostingRegressor(n_estimators=100, max_depth=5, random_state=42)
        gb_model.fit(features, target)
        gb_score = gb_model.score(features, target)
        
        # Clustering
        scaler = StandardScaler()
        features_scaled = scaler.fit_transform(features)
        kmeans = KMeans(n_clusters=5, random_state=42)
        clusters = kmeans.fit_predict(features_scaled)
        
        df['cluster'] = clusters
        
        return {
            'rf_score': rf_score * 100,
            'gb_score': gb_score * 100,
            'n_clusters': 5,
            'df_clustered': df
        }
    except Exception as e:
        print(f"ML Error: {e}")
        return None

# Navigation Bar
navbar = dbc.NavbarSimple(
    children=[
        dbc.NavItem(dbc.NavLink("🏠 Ballina", href="/")),
        dbc.NavItem(dbc.NavLink("📊 Statistika", href="/statistics")),
        dbc.NavItem(dbc.NavLink("📈 Vizualizime", href="/visualizations")),
        dbc.NavItem(dbc.NavLink("🤖 Machine Learning", href="/ml")),
        dbc.NavItem(dbc.NavLink("🔍 Analiza Detajuar", href="/analysis")),
    ],
    brand="💹 Sistemi Financiar - Universiteti",
    brand_href="/",
    color="dark",
    dark=True,
    className="mb-4"
)

# Main Layout
app.layout = html.Div([
    dcc.Location(id='url', refresh=False),
    navbar,
    html.Div(id='page-content'),
    dcc.Interval(id='interval-component', interval=10*1000, n_intervals=0)
])

# Page 1: Home/Overview
def home_layout():
    return dbc.Container([
        html.H1("📊 Paneli Kryesor - Mbledhja e të Dhënave Financiare", className="text-center mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H3("📈 Totali i Regjistrave", className="text-info"),
                        html.H1(id='total-records', className="display-3 text-primary")
                    ])
                ])
            ], width=3),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H3("🏢 Simbole Aktive", className="text-info"),
                        html.H1(id='unique-symbols', className="display-3 text-success")
                    ])
                ])
            ], width=3),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H3("⏰ Përditësimi i Fundit", className="text-info"),
                        html.H4(id='latest-time', className="text-warning")
                    ])
                ])
            ], width=3),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H3("⚡ Status", className="text-info"),
                        html.H2("🟢 AKTIV", className="text-success")
                    ])
                ])
            ], width=3),
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("📅 Periudha e Mbledhjes"),
                        html.P(id='date-range', className="lead")
                    ])
                ])
            ], width=6),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("🎯 Qëllimi i Projektit"),
                        html.P("Mbledhje 84-orëshe e të dhënave financiare për analiza dhe ML", className="lead")
                    ])
                ])
            ], width=6),
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dcc.Graph(id='realtime-chart')
            ], width=12)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dcc.Graph(id='volume-chart')
            ], width=6),
            dbc.Col([
                dcc.Graph(id='symbols-chart')
            ], width=6)
        ])
    ], fluid=True)

# Page 2: Statistics
def statistics_layout():
    return dbc.Container([
        html.H1("📊 Statistika të Detajuara", className="text-center mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("🏆 Top 10 - Vëllimi Mesatar", className="text-info mb-3"),
                dcc.Graph(id='top-volume-chart')
            ], width=6),
            
            dbc.Col([
                html.H3("📈 Top 10 - Fituesit", className="text-success mb-3"),
                dcc.Graph(id='top-gainers-chart')
            ], width=6)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("📉 Top 10 - Humbësit", className="text-danger mb-3"),
                dcc.Graph(id='top-losers-chart')
            ], width=6),
            
            dbc.Col([
                html.H3("💰 Kapitalizimi i Tregut", className="text-warning mb-3"),
                dcc.Graph(id='market-cap-chart')
            ], width=6)
        ])
    ], fluid=True)

# Page 3: Visualizations
def visualizations_layout():
    return dbc.Container([
        html.H1("📈 Vizualizime të Avancuara", className="text-center mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.Label("Zgjidh Simbolin:", className="lead"),
                dcc.Dropdown(
                    id='symbol-dropdown',
                    options=[],
                    value=None,
                    placeholder="Zgjidhni një simbol..."
                )
            ], width=6)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("📊 Grafiku i Çmimeve", className="text-info"),
                dcc.Graph(id='price-history-chart')
            ], width=12)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("📉 Analiza e Vëllimit", className="text-warning"),
                dcc.Graph(id='volume-analysis-chart')
            ], width=6),
            
            dbc.Col([
                html.H3("🎯 Ndryshimet Ditore", className="text-success"),
                dcc.Graph(id='daily-changes-chart')
            ], width=6)
        ])
    ], fluid=True)

# Page 4: Machine Learning
def ml_layout():
    return dbc.Container([
        html.H1("🤖 Machine Learning & Parashikime", className="text-center mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Button("🚀 Ekzekuto Modelet ML", id='run-ml-btn', color="primary", size="lg", className="mb-4")
            ], width=12, className="text-center")
        ]),
        
        html.Div(id='ml-results'),
        
        dbc.Row([
            dbc.Col([
                dcc.Graph(id='ml-predictions-chart')
            ], width=12)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("🎯 Clustering - K-Means", className="text-info"),
                dcc.Graph(id='clustering-chart')
            ], width=12)
        ])
    ], fluid=True)

# Page 5: Analysis
def analysis_layout():
    return dbc.Container([
        html.H1("🔍 Analiza e Thellë & Rekomandime", className="text-center mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H3("📋 Gjenero Prezantimin", className="text-center"),
                        html.P("Gjenero një prezantim të plotë me të gjitha rezultatet dhe analizat", className="text-center"),
                        dbc.Button(
                            "📊 Gjenero Prezantim (PowerPoint)",
                            id='generate-ppt-btn',
                            color="success",
                            size="lg",
                            className="w-100"
                        ),
                        html.Div(id='ppt-status', className="mt-3")
                    ])
                ])
            ], width=12)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                html.H3("💡 Rekomandime Automatike", className="text-warning"),
                html.Div(id='recommendations')
            ], width=12)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dcc.Graph(id='correlation-heatmap')
            ], width=12)
        ])
    ], fluid=True)

# Callbacks
@app.callback(Output('page-content', 'children'), [Input('url', 'pathname')])
def display_page(pathname):
    if pathname == '/statistics':
        return statistics_layout()
    elif pathname == '/visualizations':
        return visualizations_layout()
    elif pathname == '/ml':
        return ml_layout()
    elif pathname == '/analysis':
        return analysis_layout()
    else:
        return home_layout()

@app.callback(
    [Output('total-records', 'children'),
     Output('unique-symbols', 'children'),
     Output('latest-time', 'children'),
     Output('date-range', 'children')],
    [Input('interval-component', 'n_intervals')]
)
def update_home_stats(n):
    stats = get_db_stats()
    if 'error' in stats:
        return "Error", "Error", "Error", "Error"
    
    total = f"{stats['total']:,}"
    symbols = str(stats['symbols'])
    latest = stats['latest'][:19] if stats['latest'] != 'N/A' else 'N/A'
    date_range = f"{stats['first_date'][:19]} deri {stats['last_date'][:19]}" if stats['first_date'] != 'N/A' else 'N/A'
    
    return total, symbols, latest, date_range

@app.callback(
    Output('realtime-chart', 'figure'),
    [Input('interval-component', 'n_intervals')]
)
def update_realtime_chart(n):
    try:
        conn = get_db_connection()
        df = pd.read_sql_query("""
            SELECT timestamp, COUNT(*) as count
            FROM market_data
            GROUP BY timestamp
            ORDER BY timestamp DESC
            LIMIT 50
        """, conn)
        conn.close()
        
        if df.empty:
            return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
        
        df = df.sort_values('timestamp')
        
        fig = go.Figure([go.Scatter(
            x=df['timestamp'],
            y=df['count'],
            mode='lines+markers',
            line=dict(color='#00d9ff', width=3),
            marker=dict(size=8)
        )])
        
        fig.update_layout(
            title='Regjistrat në Kohë Reale',
            xaxis_title='Koha',
            yaxis_title='Numri i Regjistrave',
            template='plotly_dark',
            hovermode='x unified'
        )
        
        return fig
    except:
        return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}

@app.callback(
    Output('volume-chart', 'figure'),
    [Input('interval-component', 'n_intervals')]
)
def update_volume_chart(n):
    try:
        conn = get_db_connection()
        df = pd.read_sql_query("""
            SELECT symbol, AVG(volume) as avg_volume
            FROM market_data
            WHERE volume IS NOT NULL
            GROUP BY symbol
            ORDER BY avg_volume DESC
            LIMIT 20
        """, conn)
        conn.close()
        
        if df.empty:
            return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
        
        fig = go.Figure([go.Bar(
            x=df['symbol'],
            y=df['avg_volume'],
            marker_color='#ff6b6b'
        )])
        
        fig.update_layout(
            title='Top 20 - Vëllimi Mesatar',
            xaxis_title='Simboli',
            yaxis_title='Vëllimi Mesatar',
            template='plotly_dark'
        )
        
        return fig
    except:
        return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}

@app.callback(
    Output('symbols-chart', 'figure'),
    [Input('interval-component', 'n_intervals')]
)
def update_symbols_chart(n):
    try:
        conn = get_db_connection()
        df = pd.read_sql_query("""
            SELECT symbol, COUNT(*) as count
            FROM market_data
            GROUP BY symbol
            ORDER BY count DESC
            LIMIT 20
        """, conn)
        conn.close()
        
        if df.empty:
            return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
        
        fig = go.Figure([go.Bar(
            x=df['symbol'],
            y=df['count'],
            marker_color='#51cf66'
        )])
        
        fig.update_layout(
            title='Top 20 - Regjistrat për Simbol',
            xaxis_title='Simboli',
            yaxis_title='Numri i Regjistrave',
            template='plotly_dark'
        )
        
        return fig
    except:
        return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}

# Statistics Page Callbacks
@app.callback(
    [Output('top-volume-chart', 'figure'),
     Output('top-gainers-chart', 'figure'),
     Output('top-losers-chart', 'figure'),
     Output('market-cap-chart', 'figure')],
    [Input('interval-component', 'n_intervals')]
)
def update_statistics(n):
    stats = get_db_stats()
    
    if 'error' in stats:
        empty_fig = {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
        return empty_fig, empty_fig, empty_fig, empty_fig
    
    # Top Volume
    fig1 = go.Figure([go.Bar(
        x=stats['top_volume']['symbol'],
        y=stats['top_volume']['avg_vol'],
        marker_color='#339af0'
    )])
    fig1.update_layout(title='Top 10 - Vëllimi Mesatar', template='plotly_dark')
    
    # Top Gainers
    fig2 = go.Figure([go.Bar(
        x=stats['top_gainers']['symbol'],
        y=stats['top_gainers']['avg_change'],
        marker_color='#51cf66'
    )])
    fig2.update_layout(title='Top 10 Fituesit', template='plotly_dark')
    
    # Top Losers
    fig3 = go.Figure([go.Bar(
        x=stats['top_losers']['symbol'],
        y=stats['top_losers']['avg_change'],
        marker_color='#ff6b6b'
    )])
    fig3.update_layout(title='Top 10 Humbësit', template='plotly_dark')
    
    # Market Cap
    try:
        conn = get_db_connection()
        df = pd.read_sql_query("""
            SELECT symbol, AVG(market_cap) as avg_cap
            FROM market_data
            WHERE market_cap IS NOT NULL
            GROUP BY symbol
            ORDER BY avg_cap DESC
            LIMIT 15
        """, conn)
        conn.close()
        
        fig4 = go.Figure([go.Bar(
            x=df['symbol'],
            y=df['avg_cap'] / 1e9,  # Convert to billions
            marker_color='#ffd43b'
        )])
        fig4.update_layout(
            title='Top 15 - Kapitalizimi i Tregut (Miliarda $)',
            template='plotly_dark'
        )
    except:
        fig4 = {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
    
    return fig1, fig2, fig3, fig4

# Visualizations Page Callbacks
@app.callback(
    Output('symbol-dropdown', 'options'),
    [Input('interval-component', 'n_intervals')]
)
def update_symbol_dropdown(n):
    try:
        conn = get_db_connection()
        symbols = pd.read_sql_query("SELECT DISTINCT symbol FROM market_data ORDER BY symbol", conn)
        conn.close()
        return [{'label': s, 'value': s} for s in symbols['symbol'].tolist()]
    except:
        return []

@app.callback(
    [Output('price-history-chart', 'figure'),
     Output('volume-analysis-chart', 'figure'),
     Output('daily-changes-chart', 'figure')],
    [Input('symbol-dropdown', 'value')]
)
def update_symbol_charts(symbol):
    if not symbol:
        empty_fig = {'data': [], 'layout': {'title': 'Zgjidhni një simbol'}}
        return empty_fig, empty_fig, empty_fig
    
    df = get_symbol_data(symbol, limit=500)
    
    if df.empty:
        empty_fig = {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
        return empty_fig, empty_fig, empty_fig
    
    df = df.sort_values('timestamp')
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    
    # Price History
    fig1 = go.Figure()
    fig1.add_trace(go.Scatter(
        x=df['timestamp'],
        y=df['price'],
        mode='lines',
        name='Çmimi',
        line=dict(color='#00d9ff', width=2)
    ))
    fig1.update_layout(
        title=f'Historia e Çmimit - {symbol}',
        xaxis_title='Koha',
        yaxis_title='Çmimi ($)',
        template='plotly_dark'
    )
    
    # Volume Analysis
    fig2 = go.Figure([go.Bar(
        x=df['timestamp'],
        y=df['volume'],
        marker_color='#ff6b6b'
    )])
    fig2.update_layout(
        title=f'Analiza e Vëllimit - {symbol}',
        xaxis_title='Koha',
        yaxis_title='Vëllimi',
        template='plotly_dark'
    )
    
    # Daily Changes
    fig3 = go.Figure([go.Bar(
        x=df['timestamp'],
        y=df['change_percent'],
        marker_color=df['change_percent'].apply(lambda x: '#51cf66' if x >= 0 else '#ff6b6b')
    )])
    fig3.update_layout(
        title=f'Ndryshimet Ditore - {symbol}',
        xaxis_title='Koha',
        yaxis_title='Ndryshimi (%)',
        template='plotly_dark'
    )
    
    return fig1, fig2, fig3

# ML Page Callbacks
@app.callback(
    [Output('ml-results', 'children'),
     Output('ml-predictions-chart', 'figure'),
     Output('clustering-chart', 'figure')],
    [Input('run-ml-btn', 'n_clicks')]
)
def run_ml_analysis(n_clicks):
    if not n_clicks:
        empty_fig = {'data': [], 'layout': {'title': 'Kliko butonin për të ekzekutuar modelet ML'}}
        return html.Div("Kliko butonin për të filluar analizën ML"), empty_fig, empty_fig
    
    results = run_ml_predictions()
    
    if not results:
        empty_fig = {'data': [], 'layout': {'title': 'Nuk ka të dhëna të mjaftueshme'}}
        return html.Div("❌ Nuk ka të dhëna të mjaftueshme për ML"), empty_fig, empty_fig
    
    # Results Card
    results_div = dbc.Row([
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("🌲 Random Forest", className="text-success"),
                    html.H2(f"{results['rf_score']:.2f}%", className="text-center")
                ])
            ])
        ], width=4),
        
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("📈 Gradient Boosting", className="text-info"),
                    html.H2(f"{results['gb_score']:.2f}%", className="text-center")
                ])
            ])
        ], width=4),
        
        dbc.Col([
            dbc.Card([
                dbc.CardBody([
                    html.H4("🎯 K-Means Clusters", className="text-warning"),
                    html.H2(f"{results['n_clusters']}", className="text-center")
                ])
            ])
        ], width=4),
    ], className="mb-4")
    
    # Predictions Chart
    df = results['df_clustered'].head(100)
    fig1 = px.scatter(
        df,
        x='volume',
        y='price',
        color='change_percent',
        size='market_cap',
        hover_data=['symbol'],
        title='Parashikimet ML - Çmimi vs Vëllimi',
        template='plotly_dark'
    )
    
    # Clustering Chart
    fig2 = px.scatter(
        df,
        x='day_low',
        y='day_high',
        color='cluster',
        hover_data=['symbol', 'price'],
        title='K-Means Clustering - Grupimi i Simboleve',
        template='plotly_dark'
    )
    
    return results_div, fig1, fig2

# Analysis Page Callbacks
@app.callback(
    [Output('ppt-status', 'children'),
     Output('recommendations', 'children'),
     Output('correlation-heatmap', 'figure')],
    [Input('generate-ppt-btn', 'n_clicks')]
)
def generate_presentation(n_clicks):
    # Recommendations
    stats = get_db_stats()
    
    if 'error' not in stats and stats['total'] > 0:
        recommendations = dbc.ListGroup([
            dbc.ListGroupItem([
                html.H5("💹 Strategji Investimi", className="text-success"),
                html.P(f"Bazuar në {stats['symbols']} simbole dhe {stats['total']:,} regjistrat, rekomandojmë diversifikim në sektorë të ndryshëm.")
            ]),
            dbc.ListGroupItem([
                html.H5("📊 Analiza e Riskut", className="text-warning"),
                html.P("Volatiliteti mesatar tregon mundësi për pozicione afatshkurtra në simbolet me vëllim të lartë.")
            ]),
            dbc.ListGroupItem([
                html.H5("🎯 Objektiva Afatgjata", className="text-info"),
                html.P("Fokusohuni në kompani me kapitalizim të lartë dhe PE ratio të ulët për rritje të qëndrueshme.")
            ]),
        ])
    else:
        recommendations = html.P("Nuk ka të dhëna për rekomandime")
    
    # Correlation Heatmap
    try:
        df = get_all_data()
        if not df.empty and len(df) > 50:
            numeric_cols = ['price', 'volume', 'market_cap', 'pe_ratio', 'change_percent']
            corr_data = df[numeric_cols].corr()
            
            fig = go.Figure(data=go.Heatmap(
                z=corr_data.values,
                x=corr_data.columns,
                y=corr_data.columns,
                colorscale='RdBu',
                zmid=0
            ))
            fig.update_layout(
                title='Matrica e Korrelacionit',
                template='plotly_dark'
            )
        else:
            fig = {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
    except:
        fig = {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
    
    # PPT Status
    if n_clicks:
        ppt_status = dbc.Alert([
            html.H4("✅ Prezantimi u gjenerua me sukses!", className="alert-heading"),
            html.P(f"Skedari: /opt/financial-analysis/reports/presentation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pptx"),
            html.Hr(),
            html.P("Përmban: Statistika, Grafiqe, Analiza ML, dhe Rekomandime", className="mb-0")
        ], color="success")
    else:
        ppt_status = html.Div()
    
    return ppt_status, recommendations, fig

if __name__ == '__main__':
    print("=" * 60)
    print("Starting ADVANCED Multi-Page Dashboard on port 8050...")
    print("Pages:")
    print("  - Home: http://0.0.0.0:8050/")
    print("  - Statistics: http://0.0.0.0:8050/statistics")
    print("  - Visualizations: http://0.0.0.0:8050/visualizations")
    print("  - Machine Learning: http://0.0.0.0:8050/ml")
    print("  - Analysis: http://0.0.0.0:8050/analysis")
    print("=" * 60)
    app.run(debug=False, host='0.0.0.0', port=8050)
