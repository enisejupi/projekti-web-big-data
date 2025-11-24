#!/usr/bin/env python3.9
# -*- coding: utf-8 -*-
"""
ULTRA MODERN Financial Dashboard - Enterprise Grade
Professional UI like Binance/Bloomberg with full real-time data
"""

import sqlite3
import dash
from dash import html, dcc, Input, Output, State, dash_table, callback_context
import dash_bootstrap_components as dbc
import plotly.graph_objs as go
import plotly.express as px
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from flask import send_file
import os
import base64
from io import BytesIO

# ML Libraries
from sklearn.ensemble import RandomForestRegressor, GradientBoostingRegressor
from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler

# Initialize Dash with modern theme
app = dash.Dash(
    __name__, 
    external_stylesheets=[
        dbc.themes.CYBORG,
        "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css"
    ],
    suppress_callback_exceptions=True
)

DB_PATH = '/opt/financial-analysis/data/market_data.db'
REPORT_DIR = '/opt/financial-analysis/reports'

# Custom CSS for modern look
app.index_string = '''
<!DOCTYPE html>
<html>
    <head>
        {%metas%}
        <title>Financial Analysis Pro</title>
        {%favicon%}
        {%css%}
        <style>
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(135deg, #0a0e27 0%, #1a1f3a 100%);
            }
            .card {
                background: rgba(30, 35, 55, 0.9) !important;
                border: 1px solid rgba(99, 179, 237, 0.2) !important;
                border-radius: 15px !important;
                box-shadow: 0 8px 32px 0 rgba(99, 179, 237, 0.1) !important;
                backdrop-filter: blur(10px);
            }
            .metric-card {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 15px;
                padding: 20px;
                margin: 10px;
                box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                transition: transform 0.3s ease;
            }
            .metric-card:hover {
                transform: translateY(-5px);
                box-shadow: 0 12px 40px 0 rgba(99, 179, 237, 0.4);
            }
            .green-glow { color: #00ff41; text-shadow: 0 0 10px #00ff41; }
            .red-glow { color: #ff0039; text-shadow: 0 0 10px #ff0039; }
            .blue-glow { color: #00d9ff; text-shadow: 0 0 10px #00d9ff; }
            .gold-glow { color: #ffd700; text-shadow: 0 0 10px #ffd700; }
            
            .navbar-custom {
                background: rgba(10, 14, 39, 0.95) !important;
                backdrop-filter: blur(10px);
                border-bottom: 2px solid #00d9ff;
                box-shadow: 0 4px 20px rgba(0, 217, 255, 0.3);
            }
            
            .btn-custom {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border: none;
                border-radius: 25px;
                padding: 12px 30px;
                font-weight: bold;
                transition: all 0.3s ease;
                box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
            }
            .btn-custom:hover {
                transform: scale(1.05);
                box-shadow: 0 6px 25px rgba(102, 126, 234, 0.6);
            }
            
            .processing-indicator {
                display: inline-block;
                width: 12px;
                height: 12px;
                border-radius: 50%;
                background: #00ff41;
                box-shadow: 0 0 20px #00ff41;
                animation: pulse 1.5s infinite;
            }
            
            @keyframes pulse {
                0%, 100% { opacity: 1; transform: scale(1); }
                50% { opacity: 0.5; transform: scale(1.2); }
            }
            
            .data-table {
                background: rgba(30, 35, 55, 0.9) !important;
                border-radius: 10px;
            }
            
            .scrollable-table {
                max-height: 600px;
                overflow-y: auto;
            }
            
            .asset-row:hover {
                background: rgba(99, 179, 237, 0.1) !important;
                cursor: pointer;
            }
        </style>
    </head>
    <body>
        {%app_entry%}
        <footer>
            {%config%}
            {%scripts%}
            {%renderer%}
        </footer>
    </body>
</html>
'''

def get_db_connection():
    """Get database connection"""
    return sqlite3.connect(DB_PATH)

def get_processing_metrics():
    """Get real-time processing metrics"""
    try:
        conn = get_db_connection()
        
        # Records per minute
        df = pd.read_sql_query("""
            SELECT 
                strftime('%Y-%m-%d %H:%M', timestamp) as minute,
                COUNT(*) as count
            FROM market_data
            GROUP BY minute
            ORDER BY minute DESC
            LIMIT 20
        """, conn)
        
        # Total processing stats
        total = pd.read_sql_query("SELECT COUNT(*) as cnt FROM market_data", conn)['cnt'].iloc[0]
        symbols = pd.read_sql_query("SELECT COUNT(DISTINCT symbol) as cnt FROM market_data", conn)['cnt'].iloc[0]
        
        # Latest timestamp
        latest = pd.read_sql_query("SELECT MAX(timestamp) as ts FROM market_data", conn)['ts'].iloc[0]
        
        # Data size estimate
        data_size = total * 0.5  # KB estimate
        
        # Processing rate (records per second)
        if not df.empty and len(df) >= 2:
            recent_count = df.head(2)['count'].sum()
            processing_rate = recent_count / 120  # per second
        else:
            processing_rate = 0
        
        conn.close()
        
        return {
            'total_records': total,
            'unique_symbols': symbols,
            'latest_timestamp': latest,
            'data_size_mb': data_size / 1024,
            'processing_rate': processing_rate,
            'records_per_minute': df
        }
    except Exception as e:
        return {
            'total_records': 0,
            'unique_symbols': 0,
            'latest_timestamp': 'N/A',
            'data_size_mb': 0,
            'processing_rate': 0,
            'records_per_minute': pd.DataFrame()
        }

def get_all_assets_data(limit=None):
    """Get ALL assets data with pagination"""
    try:
        conn = get_db_connection()
        
        # Get latest data for each symbol
        query = """
            SELECT 
                symbol,
                MAX(timestamp) as last_update,
                AVG(price) as avg_price,
                MAX(price) as high_price,
                MIN(price) as low_price,
                AVG(volume) as avg_volume,
                AVG(market_cap) as market_cap,
                AVG(pe_ratio) as pe_ratio,
                AVG(change_percent) as change_pct,
                COUNT(*) as data_points
            FROM market_data
            GROUP BY symbol
            ORDER BY symbol
        """
        
        if limit:
            query += f" LIMIT {limit}"
        
        df = pd.read_sql_query(query, conn)
        conn.close()
        
        return df
    except:
        return pd.DataFrame()

def get_symbol_history(symbol, limit=1000):
    """Get full history for a symbol"""
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

# Enhanced Navigation Bar
navbar = dbc.Navbar(
    dbc.Container([
        html.A(
            dbc.Row([
                dbc.Col(html.I(className="fas fa-chart-line fa-2x", style={'color': '#00d9ff'})),
                dbc.Col(dbc.NavbarBrand("FINANCIAL ANALYSIS PRO", className="ms-2", style={
                    'fontSize': '24px',
                    'fontWeight': 'bold',
                    'color': '#00d9ff',
                    'textShadow': '0 0 20px rgba(0, 217, 255, 0.5)'
                })),
            ], align="center", className="g-0"),
            href="/",
            style={"textDecoration": "none"},
        ),
        dbc.NavbarToggler(id="navbar-toggler"),
        dbc.Collapse([
            dbc.Nav([
                dbc.NavItem(dbc.NavLink([html.I(className="fas fa-home me-2"), "Ballina"], href="/", className="mx-2")),
                dbc.NavItem(dbc.NavLink([html.I(className="fas fa-chart-bar me-2"), "Të Gjitha Asetet"], href="/all-assets", className="mx-2")),
                dbc.NavItem(dbc.NavLink([html.I(className="fas fa-chart-line me-2"), "Analiza Live"], href="/live", className="mx-2")),
                dbc.NavItem(dbc.NavLink([html.I(className="fas fa-robot me-2"), "Machine Learning"], href="/ml", className="mx-2")),
                dbc.NavItem(dbc.NavLink([html.I(className="fas fa-file-powerpoint me-2"), "Raporte"], href="/reports", className="mx-2")),
            ], className="ms-auto", navbar=True)
        ], id="navbar-collapse", navbar=True),
    ], fluid=True),
    color="dark",
    dark=True,
    className="navbar-custom mb-4",
    sticky="top"
)

# Main Layout
app.layout = html.Div([
    dcc.Location(id='url', refresh=False),
    navbar,
    
    # Real-time processing indicator
    dbc.Container([
        dbc.Row([
            dbc.Col([
                html.Div([
                    html.Span(className="processing-indicator me-2"),
                    html.Span("LIVE DATA PROCESSING", className="green-glow", style={'fontWeight': 'bold'}),
                    html.Span(id='live-time', className="ms-3", style={'color': '#888'})
                ], className="text-center mb-3")
            ])
        ])
    ], fluid=True),
    
    html.Div(id='page-content'),
    
    # Multiple intervals for different update rates
    dcc.Interval(id='fast-interval', interval=2*1000, n_intervals=0),  # 2 seconds for metrics
    dcc.Interval(id='medium-interval', interval=5*1000, n_intervals=0),  # 5 seconds for charts
    dcc.Interval(id='slow-interval', interval=10*1000, n_intervals=0),  # 10 seconds for tables
    
    # Download component
    dcc.Download(id="download-presentation")
])

# Page 1: Modern Home with Real-time Metrics
def home_layout():
    metrics = get_processing_metrics()
    
    return dbc.Container([
        # Processing Metrics Row
        dbc.Row([
            dbc.Col([
                html.Div([
                    html.I(className="fas fa-database fa-3x mb-3", style={'color': '#00d9ff'}),
                    html.H2(id='total-records-home', className="display-4 blue-glow"),
                    html.P("Total Records", className="text-muted")
                ], className="metric-card text-center")
            ], width=12, md=6, lg=3),
            
            dbc.Col([
                html.Div([
                    html.I(className="fas fa-coins fa-3x mb-3", style={'color': '#ffd700'}),
                    html.H2(id='unique-symbols-home', className="display-4 gold-glow"),
                    html.P("Active Symbols", className="text-muted")
                ], className="metric-card text-center")
            ], width=12, md=6, lg=3),
            
            dbc.Col([
                html.Div([
                    html.I(className="fas fa-tachometer-alt fa-3x mb-3", style={'color': '#00ff41'}),
                    html.H2(id='processing-rate', className="display-4 green-glow"),
                    html.P("Records/Second", className="text-muted")
                ], className="metric-card text-center")
            ], width=12, md=6, lg=3),
            
            dbc.Col([
                html.Div([
                    html.I(className="fas fa-hdd fa-3x mb-3", style={'color': '#ff0039'}),
                    html.H2(id='data-size', className="display-4 red-glow"),
                    html.P("Data Size (MB)", className="text-muted")
                ], className="metric-card text-center")
            ], width=12, md=6, lg=3),
        ], className="mb-4"),
        
        # Real-time Processing Chart
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4([
                            html.I(className="fas fa-chart-area me-2"),
                            "Real-Time Data Processing"
                        ], className="blue-glow"),
                        dcc.Graph(id='processing-chart', config={'displayModeBar': False})
                    ])
                ])
            ], width=12)
        ], className="mb-4"),
        
        # Top Performers
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4([
                            html.I(className="fas fa-trophy me-2"),
                            "Top Gainers (24h)"
                        ], className="green-glow"),
                        dcc.Graph(id='top-gainers-home', config={'displayModeBar': False})
                    ])
                ])
            ], width=6),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4([
                            html.I(className="fas fa-arrow-down me-2"),
                            "Top Losers (24h)"
                        ], className="red-glow"),
                        dcc.Graph(id='top-losers-home', config={'displayModeBar': False})
                    ])
                ])
            ], width=6)
        ])
    ], fluid=True)

# Page 2: All Assets with Full Data Table
def all_assets_layout():
    return dbc.Container([
        dbc.Row([
            dbc.Col([
                html.H2([
                    html.I(className="fas fa-list me-3"),
                    "All Assets - Live Data"
                ], className="blue-glow mb-4")
            ])
        ]),
        
        # Search and Filter
        dbc.Row([
            dbc.Col([
                dbc.InputGroup([
                    dbc.InputGroupText(html.I(className="fas fa-search")),
                    dbc.Input(id='search-symbol', placeholder="Search symbol...", type="text")
                ])
            ], width=12, md=6),
            
            dbc.Col([
                dbc.Select(
                    id='sort-column',
                    options=[
                        {'label': 'Symbol', 'value': 'symbol'},
                        {'label': 'Price', 'value': 'avg_price'},
                        {'label': 'Change %', 'value': 'change_pct'},
                        {'label': 'Volume', 'value': 'avg_volume'},
                        {'label': 'Market Cap', 'value': 'market_cap'},
                    ],
                    value='symbol'
                )
            ], width=12, md=3),
            
            dbc.Col([
                dbc.Button([
                    html.I(className="fas fa-sync-alt me-2"),
                    "Refresh"
                ], id='refresh-assets', color="primary", className="w-100")
            ], width=12, md=3)
        ], className="mb-4"),
        
        # Assets Count
        dbc.Row([
            dbc.Col([
                html.H5(id='assets-count', className="text-info mb-3")
            ])
        ]),
        
        # Full Assets Table
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.Div([
                            dash_table.DataTable(
                                id='assets-table',
                                columns=[
                                    {'name': '🏢 Symbol', 'id': 'symbol'},
                                    {'name': '💰 Price ($)', 'id': 'avg_price', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': '📈 High ($)', 'id': 'high_price', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': '📉 Low ($)', 'id': 'low_price', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': '📊 Volume', 'id': 'avg_volume', 'type': 'numeric', 'format': {'specifier': ',.0f'}},
                                    {'name': '💎 Market Cap', 'id': 'market_cap', 'type': 'numeric', 'format': {'specifier': ',.0f'}},
                                    {'name': '📐 P/E Ratio', 'id': 'pe_ratio', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': '🔄 Change %', 'id': 'change_pct', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': '📍 Data Points', 'id': 'data_points', 'type': 'numeric'},
                                    {'name': '⏰ Last Update', 'id': 'last_update'},
                                ],
                                data=[],
                                page_size=50,
                                page_action='native',
                                sort_action='native',
                                filter_action='native',
                                row_selectable='single',
                                selected_rows=[],
                                style_table={
                                    'overflowX': 'auto',
                                    'overflowY': 'auto',
                                    'maxHeight': '600px'
                                },
                                style_cell={
                                    'textAlign': 'left',
                                    'padding': '12px',
                                    'backgroundColor': 'rgba(30, 35, 55, 0.9)',
                                    'color': '#fff',
                                    'border': '1px solid rgba(99, 179, 237, 0.2)'
                                },
                                style_header={
                                    'backgroundColor': 'rgba(102, 126, 234, 0.3)',
                                    'fontWeight': 'bold',
                                    'border': '1px solid rgba(99, 179, 237, 0.4)',
                                    'fontSize': '14px'
                                },
                                style_data_conditional=[
                                    {
                                        'if': {'column_id': 'change_pct', 'filter_query': '{change_pct} > 0'},
                                        'color': '#00ff41',
                                        'fontWeight': 'bold'
                                    },
                                    {
                                        'if': {'column_id': 'change_pct', 'filter_query': '{change_pct} < 0'},
                                        'color': '#ff0039',
                                        'fontWeight': 'bold'
                                    },
                                    {
                                        'if': {'row_index': 'odd'},
                                        'backgroundColor': 'rgba(30, 35, 55, 0.7)'
                                    }
                                ],
                                css=[{
                                    'selector': '.dash-table-container',
                                    'rule': 'font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;'
                                }]
                            )
                        ], className="scrollable-table")
                    ])
                ])
            ])
        ]),
        
        # Selected Asset Detail
        dbc.Row([
            dbc.Col([
                html.Div(id='selected-asset-detail')
            ])
        ], className="mt-4")
        
    ], fluid=True)

# Page 3: Live Analysis
def live_analysis_layout():
    return dbc.Container([
        dbc.Row([
            dbc.Col([
                html.H2([
                    html.I(className="fas fa-broadcast-tower me-3"),
                    "Live Market Analysis"
                ], className="blue-glow mb-4")
            ])
        ]),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Select Symbol for Detailed Analysis", className="text-info mb-3"),
                        dcc.Dropdown(
                            id='live-symbol-dropdown',
                            options=[],
                            value=None,
                            placeholder="Choose a symbol...",
                            style={'background': '#1a1f3a', 'color': '#fff'}
                        )
                    ])
                ])
            ])
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Price Movement (Live)", className="green-glow"),
                        dcc.Graph(id='live-price-chart', config={'displayModeBar': True})
                    ])
                ])
            ], width=8),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Quick Stats", className="gold-glow"),
                        html.Div(id='live-stats')
                    ])
                ])
            ], width=4)
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Volume Analysis", className="blue-glow"),
                        dcc.Graph(id='live-volume-chart', config={'displayModeBar': False})
                    ])
                ])
            ], width=6),
            
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Price Distribution", className="red-glow"),
                        dcc.Graph(id='live-distribution-chart', config={'displayModeBar': False})
                    ])
                ])
            ], width=6)
        ])
    ], fluid=True)

# Page 4: ML Page (Enhanced)
def ml_layout():
    return dbc.Container([
        dbc.Row([
            dbc.Col([
                html.H2([
                    html.I(className="fas fa-brain me-3"),
                    "Machine Learning Predictions"
                ], className="blue-glow mb-4")
            ])
        ]),
        
        dbc.Row([
            dbc.Col([
                dbc.Button([
                    html.I(className="fas fa-rocket me-2"),
                    "Run ML Models"
                ], id='run-ml-btn', size="lg", color="success", className="btn-custom w-100")
            ])
        ], className="mb-4"),
        
        html.Div(id='ml-results-display'),
        
        dbc.Row([
            dbc.Col([
                dcc.Graph(id='ml-clustering-chart')
            ], width=6),
            dbc.Col([
                dcc.Graph(id='ml-predictions-chart')
            ], width=6)
        ])
    ], fluid=True)

# Page 5: Reports with Auto-Download
def reports_layout():
    # Get list of existing presentations
    try:
        files = [f for f in os.listdir(REPORT_DIR) if f.endswith('.pptx')]
        files.sort(reverse=True)
    except:
        files = []
    
    return dbc.Container([
        dbc.Row([
            dbc.Col([
                html.H2([
                    html.I(className="fas fa-file-powerpoint me-3"),
                    "Reports & Presentations"
                ], className="blue-glow mb-4")
            ])
        ]),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Generate New Presentation", className="text-info mb-3"),
                        html.P("Create a comprehensive PowerPoint presentation with all analytics and insights."),
                        dbc.Button([
                            html.I(className="fas fa-magic me-2"),
                            "Generate & Download Automatically"
                        ], id='generate-ppt-btn', size="lg", color="primary", className="btn-custom w-100"),
                        html.Div(id='ppt-generation-status', className="mt-3")
                    ])
                ])
            ])
        ], className="mb-4"),
        
        dbc.Row([
            dbc.Col([
                dbc.Card([
                    dbc.CardBody([
                        html.H4("Existing Presentations", className="text-warning mb-3"),
                        html.Div([
                            dbc.ListGroup([
                                dbc.ListGroupItem([
                                    html.Div([
                                        html.I(className="fas fa-file-powerpoint me-3", style={'fontSize': '24px', 'color': '#ff6b6b'}),
                                        html.Span(f, className="me-auto"),
                                        dbc.Button([
                                            html.I(className="fas fa-download me-2"),
                                            "Download"
                                        ], id={'type': 'download-btn', 'index': f}, size="sm", color="success", className="ms-2")
                                    ], className="d-flex align-items-center justify-content-between")
                                ]) for f in files
                            ]) if files else html.P("No presentations generated yet.", className="text-muted")
                        ])
                    ])
                ])
            ])
        ])
    ], fluid=True)

# Callbacks
@app.callback(Output('page-content', 'children'), [Input('url', 'pathname')])
def display_page(pathname):
    if pathname == '/all-assets':
        return all_assets_layout()
    elif pathname == '/live':
        return live_analysis_layout()
    elif pathname == '/ml':
        return ml_layout()
    elif pathname == '/reports':
        return reports_layout()
    else:
        return home_layout()

@app.callback(
    Output('live-time', 'children'),
    [Input('fast-interval', 'n_intervals')]
)
def update_time(n):
    return datetime.now().strftime('%H:%M:%S')

@app.callback(
    [Output('total-records-home', 'children'),
     Output('unique-symbols-home', 'children'),
     Output('processing-rate', 'children'),
     Output('data-size', 'children')],
    [Input('fast-interval', 'n_intervals')]
)
def update_home_metrics(n):
    metrics = get_processing_metrics()
    return (
        f"{metrics['total_records']:,}",
        str(metrics['unique_symbols']),
        f"{metrics['processing_rate']:.2f}",
        f"{metrics['data_size_mb']:.2f}"
    )

@app.callback(
    Output('processing-chart', 'figure'),
    [Input('medium-interval', 'n_intervals')]
)
def update_processing_chart(n):
    metrics = get_processing_metrics()
    df = metrics['records_per_minute']
    
    if df.empty:
        return {'data': [], 'layout': {'title': 'Waiting for data...'}}
    
    # Reverse to show chronological order
    df = df.sort_values('minute')
    
    fig = go.Figure()
    
    fig.add_trace(go.Scatter(
        x=df['minute'],
        y=df['count'],
        mode='lines+markers',
        fill='tozeroy',
        line=dict(color='#00d9ff', width=3),
        marker=dict(size=8, color='#00ff41'),
        name='Records'
    ))
    
    fig.update_layout(
        template='plotly_dark',
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        xaxis_title='Time',
        yaxis_title='Records Processed',
        hovermode='x unified',
        showlegend=False,
        margin=dict(l=40, r=40, t=40, b=40)
    )
    
    return fig

@app.callback(
    [Output('top-gainers-home', 'figure'),
     Output('top-losers-home', 'figure')],
    [Input('medium-interval', 'n_intervals')]
)
def update_top_movers(n):
    try:
        conn = get_db_connection()
        
        gainers = pd.read_sql_query("""
            SELECT symbol, AVG(change_percent) as change
            FROM market_data
            WHERE change_percent IS NOT NULL AND change_percent > 0
            GROUP BY symbol
            ORDER BY change DESC
            LIMIT 10
        """, conn)
        
        losers = pd.read_sql_query("""
            SELECT symbol, AVG(change_percent) as change
            FROM market_data
            WHERE change_percent IS NOT NULL AND change_percent < 0
            GROUP BY symbol
            ORDER BY change ASC
            LIMIT 10
        """, conn)
        
        conn.close()
        
        # Gainers chart
        fig1 = go.Figure()
        fig1.add_trace(go.Bar(
            x=gainers['symbol'],
            y=gainers['change'],
            marker=dict(
                color=gainers['change'],
                colorscale='Greens',
                showscale=False
            ),
            text=gainers['change'].apply(lambda x: f'+{x:.2f}%'),
            textposition='outside'
        ))
        fig1.update_layout(
            template='plotly_dark',
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            showlegend=False,
            margin=dict(l=40, r=40, t=20, b=40),
            yaxis_title='Change %'
        )
        
        # Losers chart
        fig2 = go.Figure()
        fig2.add_trace(go.Bar(
            x=losers['symbol'],
            y=losers['change'],
            marker=dict(
                color=losers['change'],
                colorscale='Reds',
                showscale=False,
                reversescale=True
            ),
            text=losers['change'].apply(lambda x: f'{x:.2f}%'),
            textposition='outside'
        ))
        fig2.update_layout(
            template='plotly_dark',
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            showlegend=False,
            margin=dict(l=40, r=40, t=20, b=40),
            yaxis_title='Change %'
        )
        
        return fig1, fig2
    except:
        empty = {'data': [], 'layout': {'template': 'plotly_dark', 'paper_bgcolor': 'rgba(0,0,0,0)'}}
        return empty, empty

@app.callback(
    [Output('assets-table', 'data'),
     Output('assets-count', 'children')],
    [Input('slow-interval', 'n_intervals'),
     Input('refresh-assets', 'n_clicks'),
     Input('search-symbol', 'value'),
     Input('sort-column', 'value')]
)
def update_assets_table(n, clicks, search, sort_col):
    df = get_all_assets_data()
    
    if df.empty:
        return [], "No data available"
    
    # Search filter
    if search:
        df = df[df['symbol'].str.contains(search.upper(), na=False)]
    
    # Sort
    if sort_col:
        df = df.sort_values(sort_col, ascending=False)
    
    count = len(df)
    
    return df.to_dict('records'), f"📊 Showing {count} assets"

# Add Flask route for file downloads
@app.server.route('/download/<path:filename>')
def download_file(filename):
    """Download presentation file"""
    filepath = os.path.join(REPORT_DIR, filename)
    if os.path.exists(filepath):
        return send_file(filepath, as_attachment=True)
    return "File not found", 404

@app.callback(
    [Output('ppt-generation-status', 'children'),
     Output('download-presentation', 'data')],
    [Input('generate-ppt-btn', 'n_clicks')],
    prevent_initial_call=True
)
def generate_and_download_ppt(n_clicks):
    if not n_clicks:
        return "", None
    
    try:
        # Import presentation generator
        import sys
        sys.path.append('/opt/financial-analysis/scripts')
        from generate_presentation import generate_presentation
        
        filename = generate_presentation()
        
        if filename:
            status = dbc.Alert([
                html.I(className="fas fa-check-circle me-2"),
                f"Presentation generated successfully! Downloading..."
            ], color="success")
            
            # Trigger download
            return status, dcc.send_file(filename)
        else:
            return dbc.Alert("Failed to generate presentation", color="danger"), None
            
    except Exception as e:
        return dbc.Alert(f"Error: {str(e)}", color="danger"), None

@app.callback(
    [Output('ml-results-display', 'children'),
     Output('ml-clustering-chart', 'figure'),
     Output('ml-predictions-chart', 'figure')],
    [Input('run-ml-btn', 'n_clicks')],
    prevent_initial_call=True
)
def run_ml_models(n_clicks):
    """Run ML predictions and display results"""
    if not n_clicks:
        empty_fig = {'data': [], 'layout': {'template': 'plotly_dark', 'paper_bgcolor': 'rgba(0,0,0,0)'}}
        return html.Div(), empty_fig, empty_fig
    
    try:
        # Trigger ML job on Spark cluster
        import subprocess
        
        # Submit Spark job for ML predictions
        result = subprocess.run([
            '/opt/spark/bin/spark-submit',
            '--master', 'spark://10.0.0.4:7077',
            '--executor-memory', '130g',
            '--driver-memory', '120g',
            '--executor-cores', '16',
            '--total-executor-cores', '144',
            '/opt/financial-analysis/spark_apps/periodic_predictions.py'
        ], capture_output=True, text=True, timeout=300)
        
        if result.returncode != 0:
            return dbc.Alert([
                html.I(className="fas fa-exclamation-triangle me-2"),
                f"ML job failed: {result.stderr}"
            ], color="danger"), {'data': [], 'layout': {'template': 'plotly_dark'}}, {'data': [], 'layout': {'template': 'plotly_dark'}}
        
        # Load the latest predictions
        import pyarrow.parquet as pq
        
        predictions_path = '/opt/financial-analysis/data/predictions/latest_predictions.parquet'
        if not os.path.exists(predictions_path):
            return dbc.Alert("Predictions file not found", color="warning"), {'data': [], 'layout': {'template': 'plotly_dark'}}, {'data': [], 'layout': {'template': 'plotly_dark'}}
        
        # Read predictions
        table = pq.read_table(predictions_path)
        df_pred = table.to_pandas()
        
        # Display results
        results_display = dbc.Container([
            dbc.Row([
                dbc.Col([
                    html.H4("✓ ML Models Executed Successfully", className="text-success mb-3")
                ])
            ]),
            
            dbc.Row([
                dbc.Col([
                    html.Div([
                        html.I(className="fas fa-chart-line fa-2x mb-2", style={'color': '#00ff41'}),
                        html.H3(f"{len(df_pred)}", className="green-glow"),
                        html.P("Predictions Made")
                    ], className="metric-card text-center")
                ], width=3),
                
                dbc.Col([
                    html.Div([
                        html.I(className="fas fa-thumbs-up fa-2x mb-2", style={'color': '#00d9ff'}),
                        html.H3(f"{(df_pred['recommendation'] == 'BUY').sum() + (df_pred['recommendation'] == 'STRONG BUY').sum()}", 
                                className="blue-glow"),
                        html.P("Buy Signals")
                    ], className="metric-card text-center")
                ], width=3),
                
                dbc.Col([
                    html.Div([
                        html.I(className="fas fa-minus fa-2x mb-2", style={'color': '#ffd700'}),
                        html.H3(f"{(df_pred['recommendation'] == 'HOLD').sum()}", className="gold-glow"),
                        html.P("Hold Signals")
                    ], className="metric-card text-center")
                ], width=3),
                
                dbc.Col([
                    html.Div([
                        html.I(className="fas fa-thumbs-down fa-2x mb-2", style={'color': '#ff0039'}),
                        html.H3(f"{(df_pred['recommendation'] == 'SELL').sum() + (df_pred['recommendation'] == 'STRONG SELL').sum()}", 
                                className="red-glow"),
                        html.P("Sell Signals")
                    ], className="metric-card text-center")
                ], width=3)
            ], className="mb-4"),
            
            dbc.Row([
                dbc.Col([
                    dbc.Card([
                        dbc.CardBody([
                            html.H5("Top Predictions", className="text-info mb-3"),
                            dash_table.DataTable(
                                columns=[
                                    {'name': 'Symbol', 'id': 'symbol'},
                                    {'name': 'Current Price', 'id': 'close', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': 'Predicted Return %', 'id': 'ensemble_prediction', 'type': 'numeric', 'format': {'specifier': ',.2f'}},
                                    {'name': 'Recommendation', 'id': 'recommendation'},
                                    {'name': 'Score', 'id': 'invest_score', 'type': 'numeric'},
                                ],
                                data=df_pred.nlargest(20, 'invest_score')[['symbol', 'close', 'ensemble_prediction', 'recommendation', 'invest_score']].to_dict('records'),
                                style_table={'overflowX': 'auto'},
                                style_cell={
                                    'textAlign': 'left',
                                    'padding': '10px',
                                    'backgroundColor': 'rgba(30, 35, 55, 0.9)',
                                    'color': '#fff'
                                },
                                style_header={
                                    'backgroundColor': 'rgba(102, 126, 234, 0.3)',
                                    'fontWeight': 'bold'
                                },
                                style_data_conditional=[
                                    {
                                        'if': {'column_id': 'recommendation', 'filter_query': '{recommendation} contains "BUY"'},
                                        'color': '#00ff41',
                                        'fontWeight': 'bold'
                                    },
                                    {
                                        'if': {'column_id': 'recommendation', 'filter_query': '{recommendation} contains "SELL"'},
                                        'color': '#ff0039',
                                        'fontWeight': 'bold'
                                    }
                                ]
                            )
                        ])
                    ])
                ])
            ])
        ], fluid=True)
        
        # Clustering visualization
        if 'cluster' in df_pred.columns:
            fig_cluster = px.scatter(
                df_pred,
                x='volatility_20',
                y='ensemble_prediction',
                color='cluster',
                hover_data=['symbol', 'close'],
                title='Asset Clustering by Volatility & Predicted Return',
                color_continuous_scale='Viridis'
            )
            fig_cluster.update_layout(
                template='plotly_dark',
                paper_bgcolor='rgba(0,0,0,0)',
                plot_bgcolor='rgba(0,0,0,0)'
            )
        else:
            fig_cluster = {'data': [], 'layout': {'template': 'plotly_dark', 'paper_bgcolor': 'rgba(0,0,0,0)', 'title': 'No clustering data'}}
        
        # Predictions distribution
        fig_predictions = go.Figure()
        
        # Histogram of predictions
        fig_predictions.add_trace(go.Histogram(
            x=df_pred['ensemble_prediction'],
            nbinsx=50,
            marker=dict(
                color=df_pred['ensemble_prediction'],
                colorscale='RdYlGn',
                showscale=True
            ),
            name='Predictions'
        ))
        
        fig_predictions.update_layout(
            template='plotly_dark',
            paper_bgcolor='rgba(0,0,0,0)',
            plot_bgcolor='rgba(0,0,0,0)',
            title='Distribution of Predicted Returns',
            xaxis_title='Predicted Return (%)',
            yaxis_title='Count'
        )
        
        return results_display, fig_cluster, fig_predictions
        
    except subprocess.TimeoutExpired:
        return dbc.Alert([
            html.I(className="fas fa-clock me-2"),
            "ML job timed out. The job may still be running on the cluster."
        ], color="warning"), {'data': [], 'layout': {'template': 'plotly_dark'}}, {'data': [], 'layout': {'template': 'plotly_dark'}}
    except Exception as e:
        return dbc.Alert([
            html.I(className="fas fa-exclamation-circle me-2"),
            f"Error: {str(e)}"
        ], color="danger"), {'data': [], 'layout': {'template': 'plotly_dark'}}, {'data': [], 'layout': {'template': 'plotly_dark'}}

@app.callback(
    Output('live-symbol-dropdown', 'options'),
    [Input('slow-interval', 'n_intervals')]
)
def update_live_dropdown(n):
    df = get_all_assets_data()
    if df.empty:
        return []
    return [{'label': s, 'value': s} for s in df['symbol'].tolist()]

@app.callback(
    [Output('live-price-chart', 'figure'),
     Output('live-volume-chart', 'figure'),
     Output('live-distribution-chart', 'figure'),
     Output('live-stats', 'children')],
    [Input('live-symbol-dropdown', 'value'),
     Input('medium-interval', 'n_intervals')]
)
def update_live_analysis(symbol, n):
    if not symbol:
        empty = {'data': [], 'layout': {'template': 'plotly_dark', 'paper_bgcolor': 'rgba(0,0,0,0)', 'title': 'Select a symbol'}}
        return empty, empty, empty, html.P("Select a symbol to view details")
    
    df = get_symbol_history(symbol, limit=500)
    
    if df.empty:
        empty = {'data': [], 'layout': {'template': 'plotly_dark', 'paper_bgcolor': 'rgba(0,0,0,0)', 'title': 'No data'}}
        return empty, empty, empty, html.P("No data available")
    
    df = df.sort_values('timestamp')
    df['timestamp'] = pd.to_datetime(df['timestamp'])
    
    # Price chart with candlestick effect
    fig1 = go.Figure()
    fig1.add_trace(go.Scatter(
        x=df['timestamp'],
        y=df['price'],
        mode='lines',
        line=dict(color='#00d9ff', width=2),
        fill='tozeroy',
        fillcolor='rgba(0, 217, 255, 0.1)',
        name='Price'
    ))
    fig1.update_layout(
        template='plotly_dark',
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        xaxis_title='Time',
        yaxis_title='Price ($)',
        hovermode='x unified'
    )
    
    # Volume chart
    fig2 = go.Figure()
    fig2.add_trace(go.Bar(
        x=df['timestamp'],
        y=df['volume'],
        marker_color='#00ff41',
        name='Volume'
    ))
    fig2.update_layout(
        template='plotly_dark',
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        xaxis_title='Time',
        yaxis_title='Volume'
    )
    
    # Distribution
    fig3 = go.Figure()
    fig3.add_trace(go.Histogram(
        x=df['price'],
        marker_color='#ff6b6b',
        nbinsx=30
    ))
    fig3.update_layout(
        template='plotly_dark',
        paper_bgcolor='rgba(0,0,0,0)',
        plot_bgcolor='rgba(0,0,0,0)',
        xaxis_title='Price ($)',
        yaxis_title='Frequency'
    )
    
    # Stats
    stats = html.Div([
        html.H5(f"${df['price'].iloc[-1]:.2f}", className="blue-glow mb-3", style={'fontSize': '36px'}),
        html.Hr(),
        html.P([html.Strong("High: "), f"${df['price'].max():.2f}"], className="text-success"),
        html.P([html.Strong("Low: "), f"${df['price'].min():.2f}"], className="text-danger"),
        html.P([html.Strong("Avg: "), f"${df['price'].mean():.2f}"], className="text-info"),
        html.P([html.Strong("Volatility: "), f"{df['price'].std():.2f}"], className="text-warning"),
        html.P([html.Strong("Data Points: "), f"{len(df)}"], className="text-muted"),
    ])
    
    return fig1, fig2, fig3, stats

if __name__ == '__main__':
    print("=" * 70)
    print("🚀 ULTRA MODERN FINANCIAL DASHBOARD - ENTERPRISE EDITION")
    print("=" * 70)
    print("📊 Pages:")
    print("  • Home: http://0.0.0.0:8050/")
    print("  • All Assets: http://0.0.0.0:8050/all-assets")
    print("  • Live Analysis: http://0.0.0.0:8050/live")
    print("  • Machine Learning: http://0.0.0.0:8050/ml")
    print("  • Reports: http://0.0.0.0:8050/reports")
    print("=" * 70)
    print("✨ Features:")
    print("  ✓ Real-time data processing metrics")
    print("  ✓ ALL assets visible with full data")
    print("  ✓ Auto-download presentations")
    print("  ✓ Modern UI like Binance/Bloomberg")
    print("  ✓ Interactive expandable tables")
    print("  ✓ Live charts that DON'T extend old data")
    print("=" * 70)
    app.run(debug=False, host='0.0.0.0', port=8050)
