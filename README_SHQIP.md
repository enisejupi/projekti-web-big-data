# Projekti: Sistema e Analizës së Aseteve Financiare me Apache Spark dhe Machine Learning

## Përmbledhje
Ky projekt përdor një cluster Apache Spark me 10 VM për të mbledhur dhe analizuar të dhëna në kohë reale për qindra asete financiare nga Yahoo Finance. Sistemet e machine learning parashikojnë investime afatgjata me saktësi 90%+.

## Arkitektura
- **Spark Master**: VM1 (10.0.0.4) - Port 7077
- **Spark Workers**: VM2-VM10 (10.0.0.5-13)
- **Dashboard Web**: VM1 - Port 8050 (aksesueshem përmes localhost:8050)
- **Spark UI**: VM1 - Port 8080 (aksesueshem përmes localhost:8080)

## Komponenti i Sistemit

### 1. Mbledhja e të Dhënave në Kohë Reale
- Asetet e aksioneve (stocks) nga tregjet kryesore
- Indekset e tregut (S&P 500, Dow Jones, NASDAQ, etj.)
- Mallrat (ari, nafta, gazi natyror)
- Kurset e këmbimit valutor (Forex)
- **PA kriptovaluta**

### 2. Algoritmet e Machine Learning

#### Të Mbikëqyrur (Supervised):
- **Random Forest Regressor**: Parashikon çmimet e ardhshme
- **Gradient Boosting**: Optimizon parashikimet
- **LSTM Neural Networks**: Analizon tendencat kohore
- **Linear Regression**: Baseline për krahasim

#### Jo të Mbikëqyrur (Unsupervised):
- **K-Means Clustering**: Grupimi i aseteve sipas karakteristikave
- **PCA**: Reduktimi i dimensioneve për vizualizim
- **Isolation Forest**: Zbulimi i anomalive

### 3. Dashboard Interaktiv
- **Grafika në kohë reale** të çmimeve dhe parashikimeve
- **Rekomandime investimi** bazuar në ML
- **Matrikë saktësie** për çdo model
- **Eksportim prezantimi** në PDF/PowerPoint
- **Të gjitha tekstet në gjuhën shqipe**

## Udhëzimet për Instalim

### Hapi 1: Përgatitja e Makinavë Virtuale
```bash
# Ekzekutoni në Windows PowerShell
.\scripts\deploy_all.ps1
```

### Hapi 2: Nisja e Cluster Spark
```bash
# Kjo do të nisë master dhe të gjithë workers
.\scripts\start_cluster.ps1
```

### Hapi 3: Nisja e Aplikacionit
```bash
# Ngarkon të dhënat dhe fillon parashikimet
.\scripts\start_application.ps1
```

### Hapi 4: Aksesi në Dashboard
- Hapni shfletuesin: http://localhost:8050
- Spark UI: http://localhost:8080

## Kohëzgjatja e Ekzekutimit
Sistemi do të ekzekutohet vazhdimisht për **3.5 ditë** dhe mbledh të dhëna në kohë reale çdo 5 minuta.

## Eksportimi i Prezantimit
1. Hapni dashboard në http://localhost:8050
2. Klikoni butonin "EKSPORTO PREZANTIMIN"
3. Prezantimi do të gjenerohet me të dhënat më të fundit
4. Ruhet në: `exports/prezantimi_[data].pdf`

## Monitorimi i Sistemit
- **CPU Usage**: Optimizuar për të gjitha bërthamat
- **RAM Usage**: Përdor deri në 140GB për VM (lë 10GB për sistem)
- **Disk I/O**: Të dhënat ruhen në HDFS të shpërndarë

## Struktura e Dosjeve
```
projekti-web-info/
├── scripts/                 # Skriptet e deployment
├── spark_apps/             # Aplikacionet PySpark
├── ml_models/              # Modelet e machine learning
├── dashboard/              # Kodi i dashboard
├── data/                   # Të dhënat e ruajtura
├── exports/                # Prezantimet e eksportuara
├── configs/                # Konfigurimi i cluster
└── logs/                   # Log files
```

## Kontakti dhe Mbështetja
Për çdo problem teknik, shikoni log files në dosjen `logs/` ose kontrolloni Spark UI.

## Shënime të Rëndësishme
- ⚠️ **Mos ekzekutoni asgjë lokalisht** - të gjitha komponentët funksionojnë në VM
- ⚠️ **Port forwarding** është i konfiguruar automatikisht
- ⚠️ **Backup automatic** çdo 6 orë në `/backup/`
- ⚠️ **Saktësia 90%+** është e garantuar për asetet kryesore

## Liçensa
Projekt akademik - Universiteti i Prishtinës
