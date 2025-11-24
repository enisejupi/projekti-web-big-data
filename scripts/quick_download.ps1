# Quick Presentation Download Script
Write-Host "`n=== Downloading Presentations ===`n" -ForegroundColor Cyan

$DestFolder = "$env:USERPROFILE\Desktop\Financial-Reports"
New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null

Write-Host "Destination: $DestFolder" -ForegroundColor Yellow
Write-Host "Password: jh87qLXHzFGt6gkb9ukV`n" -ForegroundColor Gray

scp -P 8022 "krenuser@185.182.158.150:/opt/financial-analysis/reports/*.pptx" $DestFolder

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[SUCCESS] Presentations downloaded!`n" -ForegroundColor Green
    Start-Process explorer.exe -ArgumentList $DestFolder
} else {
    Write-Host "`n[INFO] No presentations found or connection failed`n" -ForegroundColor Yellow
}
