# Download presentations from server - Simple Version

Write-Host "========================================="-ForegroundColor Cyan
Write-Host " Downloading Presentations" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Create downloads folder
$downloadPath = "$env:USERPROFILE\Desktop\Presentations"
if (-not (Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    Write-Host "Created folder: $downloadPath" -ForegroundColor Green
}

Write-Host "Downloading from server..." -ForegroundColor Yellow

# Use SCP to download
scp -P 8022 "krenuser@185.182.158.150:/opt/financial-analysis/reports/*.pptx" $downloadPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "" 
    Write-Host "SUCCESS! Presentations downloaded to:" -ForegroundColor Green
    Write-Host "  $downloadPath" -ForegroundColor Cyan
    Write-Host "" 
    
    # List downloaded files
    $downloaded = Get-ChildItem -Path $downloadPath -Filter "*.pptx" -ErrorAction SilentlyContinue
    if ($downloaded) {
        Write-Host "Downloaded files:" -ForegroundColor Green
        $downloaded | ForEach-Object {
            Write-Host "  - $($_.Name) ($([math]::Round($_.Length/1KB, 2)) KB)" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "Opening folder..." -ForegroundColor Yellow
        Start-Process $downloadPath
    }
} else {
    Write-Host "No presentations found or download failed." -ForegroundColor Yellow
    Write-Host "Generating a presentation first..." -ForegroundColor Yellow
    
    # Generate presentation
    ssh -p 8022 krenuser@185.182.158.150 "cd /opt/financial-analysis/scripts; python3.9 generate_presentation.py"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Presentation generated! Downloading..." -ForegroundColor Green
        scp -P 8022 "krenuser@185.182.158.150:/opt/financial-analysis/reports/*.pptx" $downloadPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SUCCESS! Check folder: $downloadPath" -ForegroundColor Green
            Start-Process $downloadPath
        }
    }
}

Write-Host "" 
Write-Host "=========================================" -ForegroundColor Cyan
