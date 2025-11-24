#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
Financial Dashboard - SQLite Version
Displays real-time data collection progress
"""

import sqlite3
import dash
from dash import html, dcc
from dash.dependencies import Input, Output
import plotly.graph_objs as go
from datetime import datetime
import pandas as pd

app = dash.Dash(__name__)

DB_PATH = '/opt/financial-analysis/data/market_data.db'

def get_db_stats():
    """Get database statistics"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Total records
        cursor.execute("SELECT COUNT(*) FROM market_data")
        total = cursor.fetchone()[0]
        
        # Unique symbols
        cursor.execute("SELECT COUNT(DISTINCT symbol) FROM market_data")
        symbols = cursor.fetchone()[0]
        
        # Latest timestamp
        cursor.execute("SELECT MAX(timestamp) FROM market_data")
        latest = cursor.fetchone()[0]
        
        # Records per symbol (top 10)
        cursor.execute("""
            SELECT symbol, COUNT(*) as count 
            FROM market_data 
            GROUP BY symbol 
            ORDER BY count DESC 
            LIMIT 10
        """)
        top_symbols = cursor.fetchall()
        
        conn.close()
        
        return {
            'total': total,
            'symbols': symbols,
            'latest': latest,
            'top_symbols': top_symbols
        }
    except Exception as e:
        return {'error': str(e)}

def get_recent_prices(limit=100):
    """Get recent price data"""
    try:
        conn = sqlite3.connect(DB_PATH)
        df = pd.read_sql_query(f"""
            SELECT timestamp, symbol, price, volume 
            FROM market_data 
            ORDER BY timestamp DESC 
            LIMIT {limit}
        """, conn)
        conn.close()
        return df
    except Exception as e:
        return pd.DataFrame()

app.layout = html.Div([
    html.H1("📊 Mbledhja e të Dhënave Financiare", style={'textAlign': 'center', 'color': '#2c3e50'}),
    
    html.Div([
        html.Div([
            html.H3("📈 Totali i Regjistrave", style={'color': '#3498db'}),
            html.H2(id='total-records', style={'fontSize': '48px', 'color': '#2980b9'})
        ], className='stat-box', style={'padding': '20px', 'margin': '10px', 'backgroundColor': '#ecf0f1', 'borderRadius': '10px', 'width': '30%', 'display': 'inline-block'}),
        
        html.Div([
            html.H3("🏢 Simbole Unike", style={'color': '#e74c3c'}),
            html.H2(id='unique-symbols', style={'fontSize': '48px', 'color': '#c0392b'})
        ], className='stat-box', style={'padding': '20px', 'margin': '10px', 'backgroundColor': '#ecf0f1', 'borderRadius': '10px', 'width': '30%', 'display': 'inline-block'}),
        
        html.Div([
            html.H3("⏰ Kohë e Fundit", style={'color': '#27ae60'}),
            html.H2(id='latest-time', style={'fontSize': '24px', 'color': '#229954'})
        ], className='stat-box', style={'padding': '20px', 'margin': '10px', 'backgroundColor': '#ecf0f1', 'borderRadius': '10px', 'width': '30%', 'display': 'inline-block'}),
    ], style={'textAlign': 'center'}),
    
    html.Hr(),
    
    html.H3("🔥 Top 10 Simbolet më të Grumbulluara", style={'textAlign': 'center', 'color': '#34495e'}),
    dcc.Graph(id='top-symbols-chart'),
    
    html.Hr(),
    
    html.H3("💹 Çmimet e Fundit (100 Regjistrat e Fundit)", style={'textAlign': 'center', 'color': '#34495e'}),
    dcc.Graph(id='recent-prices-chart'),
    
    dcc.Interval(
        id='interval-component',
        interval=10*1000,  # Update every 10 seconds
        n_intervals=0
    )
], style={'fontFamily': 'Arial, sans-serif', 'padding': '20px'})

@app.callback(
    [Output('total-records', 'children'),
     Output('unique-symbols', 'children'),
     Output('latest-time', 'children')],
    [Input('interval-component', 'n_intervals')]
)
def update_stats(n):
    stats = get_db_stats()
    
    if 'error' in stats:
        return f"Error: {stats['error']}", "Error", "Error"
    
    total = f"{stats['total']:,}"
    symbols = str(stats['symbols'])
    latest = stats['latest'] if stats['latest'] else 'N/A'
    
    return total, symbols, latest

@app.callback(
    Output('top-symbols-chart', 'figure'),
    [Input('interval-component', 'n_intervals')]
)
def update_top_symbols(n):
    stats = get_db_stats()
    
    if 'error' in stats or not stats.get('top_symbols'):
        return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
    
    symbols = [s[0] for s in stats['top_symbols']]
    counts = [s[1] for s in stats['top_symbols']]
    
    fig = go.Figure([go.Bar(
        x=symbols,
        y=counts,
        marker_color='#3498db'
    )])
    
    fig.update_layout(
        title='Regjistrat për Simbol',
        xaxis_title='Simboli',
        yaxis_title='Numri i Regjistrave',
        template='plotly_white'
    )
    
    return fig

@app.callback(
    Output('recent-prices-chart', 'figure'),
    [Input('interval-component', 'n_intervals')]
)
def update_recent_prices(n):
    df = get_recent_prices(100)
    
    if df.empty:
        return {'data': [], 'layout': {'title': 'Nuk ka të dhëna'}}
    
    # Group by symbol and plot
    fig = go.Figure()
    
    for symbol in df['symbol'].unique()[:5]:  # Top 5 symbols
        symbol_df = df[df['symbol'] == symbol]
        fig.add_trace(go.Scatter(
            x=symbol_df['timestamp'],
            y=symbol_df['price'],
            mode='lines+markers',
            name=symbol
        ))
    
    fig.update_layout(
        title='Çmimet e Fundit (5 Simbolet e Para)',
        xaxis_title='Kohë',
        yaxis_title='Çmimi ($)',
        template='plotly_white',
        hovermode='x unified'
    )
    
    return fig

if __name__ == '__main__':
    print("Starting Dashboard on port 8050...")
    app.run(debug=False, host='0.0.0.0', port=8050)
