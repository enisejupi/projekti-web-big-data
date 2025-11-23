# Quick Start Guide - Fillo Shpejt

## 5 Hapa të Thjeshtë

### 1️⃣ Instalo PuTTY
Shkarko nga: https://www.putty.org/

### 2️⃣ Deploy në VM
```powershell
cd c:\Users\Lenovo\projekti-web-info
.\scripts\deploy_all.ps1
```
⏱ Koha: ~15 minuta

### 3️⃣ Nis Cluster
```powershell
.\scripts\start_cluster.ps1
```

### 4️⃣ Nis Aplikacionin
```powershell
.\scripts\start_application.ps1
```
⏱ Koha: 3.5 ditë (84 orë) - automatik

### 5️⃣ Port Forwarding & Akses
```bash
ssh -L 8050:10.0.0.4:8050 -L 8080:10.0.0.4:8080 -p 8022 krenuser@185.182.158.150
```
Password: `jh87qLXHzFGt6gkb9ukV`

Pastaj hap: http://localhost:8050

---

## Që të Dish

✅ **Asgjë nuk funksionon lokalisht** - gjithçka në VM  
✅ **Dashboard përditësohet automatikisht** çdo 30 sekonda  
✅ **Të dhënat mblidhen** çdo 5 minuta  
✅ **Saktësia 90%+** pas ~12 orëve  
✅ **Eksporto prezantimin** nga dashboard kur të duash  

---

## Komanda të Dobishme

**Kontrollo statusin:**
```powershell
.\scripts\check_cluster.ps1
```

**Ndalo gjithçka:**
```powershell
.\scripts\stop_application.ps1
```

**Shiko logs:**
```bash
ssh -p 8022 krenuser@185.182.158.150
tail -f /opt/financial-analysis/logs/*.log
```

---

## Në Rast Problemi

🔴 **Nuk funksionon plink?**  
→ Instalo PuTTY dhe shto në PATH

🔴 **Dashboard nuk hapet?**  
→ Sigurohu që ke bërë port forwarding me SSH

🔴 **Nuk ka të dhëna?**  
→ Prit 30 minuta pas nisjes

🔴 **Spark nuk po fillon?**  
→ Ekzekuto: `.\scripts\start_cluster.ps1` përsëri

---

## Për Prezantim (pas 3.5 ditëve)

1. Hap dashboard: http://localhost:8050
2. Shko te "📥 Eksporto Raportin"
3. Kliko "EKSPORTO PREZANTIMIN"
4. Shkarkoje prezantimin:
```powershell
pscp -P 8022 -pw jh87qLXHzFGt6gkb9ukV krenuser@185.182.158.150:/opt/financial-analysis/exports/prezantimi_*.pdf C:\Downloads\
```

---

**Dokumentim i plotë:** Shiko `UDHEZIME_DETAJ.md`

**Puna e mirë!** 🚀
