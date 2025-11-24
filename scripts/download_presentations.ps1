# Download presentations from server

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Downloading Presentations" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$password = "jh87qLXHzFGt6gkb9ukV"
$server = "krenuser@185.182.158.150"
$port = 8022

# Create downloads folder
$downloadPath = "$env:USERPROFILE\Desktop\Presentations"
if (-not (Test-Path $downloadPath)) {
    New-Item -ItemType Directory -Path $downloadPath -Force | Out-Null
    Write-Host "[*] Created folder: $downloadPath" -ForegroundColor Green
}

Write-Host "[*] Checking for presentations on server..." -ForegroundColor Yellow

# Use plink to execute command
$files = plink -P $port -pw $password $server "ls -1 /opt/financial-analysis/reports/*.pptx 2>/dev/null"

if ($LASTEXITCODE -eq 0 -and $files) {
    Write-Host "[*] Found presentations! Downloading..." -ForegroundColor Green
    
    # Download all presentations
    & pscp -P $port -pw $password "${server}:/opt/financial-analysis/reports/*.pptx" $downloadPath 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "" -ForegroundColor Green
        Write-Host "✓ Success! Presentations downloaded to:" -ForegroundColor Green
        Write-Host "  $downloadPath" -ForegroundColor Cyan
        Write-Host "" -ForegroundColor Green
        
        # List downloaded files
        $downloaded = Get-ChildItem -Path $downloadPath -Filter "*.pptx"
        if ($downloaded) {
            Write-Host "Downloaded files:" -ForegroundColor Green
            $downloaded | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor White
            }
        }
    } else {
        Write-Host "[X] Download failed. Trying alternative method..." -ForegroundColor Yellow
        
        # Alternative: use scp directly
        scp -P $port krenuser@185.182.158.150:/opt/financial-analysis/reports/*.pptx $downloadPath
    }
} else {
    Write-Host "[X] No presentations found on server." -ForegroundColor Red
    Write-Host "[*] Generating a presentation first..." -ForegroundColor Yellow
    
    # Generate presentation on server
    $genCmd = "cd /opt/financial-analysis/scripts; python3.9 generate_presentation.py"
    plink -P $port -pw $password $server $genCmd
    
    Write-Host "[*] Now downloading..." -ForegroundColor Yellow
    & pscp -P $port -pw $password "${server}:/opt/financial-analysis/reports/*.pptx" $downloadPath 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "" -ForegroundColor Green
        Write-Host "✓ Success!" -ForegroundColor Green
    }
}

Write-Host "" 
Write-Host "=========================================" -ForegroundColor Cyan
