# Udhëzime të Hollësishme për Ekzekutim

## Hapi 1: Instalimi i PuTTY (në Windows)

Ju duhet PuTTY tools për të komunikuar me VM-të:

1. Shkarkoni PuTTY nga: https://www.putty.org/
2. Instaloni dhe sigurohuni që `plink.exe` dhe `pscp.exe` janë në PATH

## Hapi 2: Deployment në VM

Hapni PowerShell si Administrator dhe ekzekutoni:

```powershell
cd c:\Users\Lenovo\projekti-web-info
.\scripts\deploy_all.ps1
```

Ky skript do të:
- Kopjojë të gjitha dosjet në 10 VM
- Instalojë Java, Python, Spark në çdo VM
- Konfigurojë Spark cluster
- Instalojë të gjitha varësitë Python

**Koha e pritshme: 15-20 minuta**

## Hapi 3: Nisja e Spark Cluster

```powershell
.\scripts\start_cluster.ps1
```

Ky skript nis:
- Spark Master në VM1
- Spark Workers në VM2-VM10

Verifikoni që cluster është aktiv:

```powershell
.\scripts\check_cluster.ps1
```

## Hapi 4: Nisja e Aplikacionit

```powershell
.\scripts\start_application.ps1
```

Ky skript do të:
1. Nisë mbledhjen e të dhënave (do të ekzekutohet për 84 orë)
2. Pritë 30 minuta për të dhëna fillestare
3. Trajnojë modelet e ML
4. Nisë dashboard-in

**RËNDËSISHME**: Ky proces do të zgjasë 3.5 ditë (84 orë). Mos e ndaloni!

## Hapi 5: Port Forwarding për Akses Lokal

Për të parë dashboard dhe Spark UI në kompjuterin tuaj lokal:

### Mënyra 1: SSH Port Forwarding (Rekomandohet)

Instaloni SSH client (GitBash ose WSL në Windows):

```bash
ssh -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -p 8022 krenuser@185.182.158.150
```

Password: `jh87qLXHzFGt6gkb9ukV`

### Mënyra 2: PuTTY Tunnel

1. Hapni PuTTY
2. Session:
   - Host: 185.182.158.150
   - Port: 8022
3. Connection > SSH > Tunnels:
   - Add: Source port 8050, Destination 10.0.0.4:8050
   - Add: Source port 8080, Destination 10.0.0.4:8080
4. Lidhu dhe fut password

## Hapi 6: Akseso Dashboard

Pas port forwarding, hapni shfletuesin:

- **Dashboard**: http://localhost:8050
- **Spark UI**: http://localhost:8080

## Hapi 7: Monitorimi

### Kontrollo statusin e cluster:

```powershell
.\scripts\check_cluster.ps1
```

### Shiko logs në kohë reale:

```bash
ssh -p 8022 krenuser@185.182.158.150
tail -f /opt/financial-analysis/logs/*.log
```

### Monitorimi i RAM dhe CPU:

```bash
ssh -p 8022 krenuser@185.182.158.150
htop
```

## Hapi 8: Eksportimi i Prezantimit

Pas 3.5 ditëve (ose në çdo kohë):

1. Hapni dashboard: http://localhost:8050
2. Shko te tab "📥 Eksporto Raportin"
3. Kliko "EKSPORTO PREZANTIMIN"
4. Prezantimi do të ruhet në: `/opt/financial-analysis/exports/`

### Shkarkimi i prezantimit në kompjuterin lokal:

```powershell
pscp -P 8022 -pw jh87qLXHzFGt6gkb9ukV krenuser@185.182.158.150:/opt/financial-analysis/exports/prezantimi_*.pdf C:\Downloads\
```

## Hapi 9: Ndalja e Aplikacionit (pas përfundimit)

```powershell
.\scripts\stop_application.ps1
```

## Troubleshooting

### Problem: "plink not found"
**Zgjidhja**: Instaloni PuTTY dhe shtoni në PATH

### Problem: "Spark Master not starting"
**Zgjidhja**: 
```bash
ssh -p 8022 krenuser@185.182.158.150
# Kontrollo logs
tail -f /opt/spark/logs/spark-*.out
# Restart
/opt/spark/sbin/stop-master.sh
/opt/spark/sbin/start-master.sh
```

### Problem: "Out of memory"
**Zgjidhja**: VM-të duhet të kenë së paku 150GB RAM. Verifikoni:
```bash
free -h
```

### Problem: "Dashboard not loading"
**Zgjidhja**: 
```bash
# Kontrollo nëse po funksionon
ps aux | grep app.py
# Restart
pkill -f app.py
cd /opt/financial-analysis/dashboard && python3.10 app.py &
```

### Problem: "No data in dashboard"
**Zgjidhja**: Pritni së paku 30 minuta pas nisjes për të dhëna fillestare

## Shënime të Rëndësishme

1. **Mos ekzekutoni asgjë lokalisht** - i gjithë processing bëhet në VM
2. **Port forwarding** është i detyrueshëm për akses lokal
3. **3.5 ditë** duhet të qëndrojë aktiv për të dhëna të mjaftueshme
4. **Backup automatik** bëhet çdo 6 orë
5. **Saktësia 90%+** arrihet pas ~12 orëve të trajnimit

## Kontakti për Probleme

Kontrolloni logs në:
- `/opt/financial-analysis/logs/data_collector.log`
- `/opt/financial-analysis/logs/ml_predictor.log`
- `/opt/financial-analysis/logs/dashboard.log`
- `/opt/spark/logs/`

## Struktura e të Dhënave

```
/opt/financial-analysis/
├── data/
│   ├── raw/                    # Të dhënat e mbledhura
│   └── predictions/            # Parashikimet
├── models/                     # Modelet e trajnuara
├── exports/                    # Prezantimet e eksportuara
└── logs/                       # Log files
```

## Prezantimi për Profesorin

Pas 3.5 ditëve:

1. Eksporto prezantimin nga dashboard
2. Shkarkoje në kompjuter
3. Shfaqe live dashboard në prezantim (me port forwarding aktiv)
4. Trego:
   - Të dhënat në kohë reale
   - Saktësinë e modeleve (duhet të jetë 90%+)
   - Rekomandimet e investimit
   - Grafiqet dhe analizat

**Sukses!** 🎓
