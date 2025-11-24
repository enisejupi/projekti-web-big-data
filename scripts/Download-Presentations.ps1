# Download Presentations from VM to Local PC# ========================================

param(# Download Presentations from VM to Local PC

    [string]$OutputFolder = "$env:USERPROFILE\Desktop\Financial-Reports"# ========================================

)

param(

Write-Host "`n============================================" -ForegroundColor Cyan    [string]$OutputFolder = "$env:USERPROFILE\Desktop\Financial-Reports"

Write-Host "  FINANCIAL PRESENTATION DOWNLOADER" -ForegroundColor Cyan)

Write-Host "============================================`n" -ForegroundColor Cyan

Write-Host "`n============================================" -ForegroundColor Cyan

# Create output folderWrite-Host "  FINANCIAL PRESENTATION DOWNLOADER" -ForegroundColor Cyan

if (-not (Test-Path $OutputFolder)) {Write-Host "============================================`n" -ForegroundColor Cyan

    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

    Write-Host "[OK] Created output folder: $OutputFolder`n" -ForegroundColor Green# Create output folder if it doesn't exist

}if (-not (Test-Path $OutputFolder)) {

    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

# VM connection details    Write-Host "✓ Created output folder: $OutputFolder`n" -ForegroundColor Green

$VMHost = "185.182.158.150"}

$VMPort = "8022"

$VMUser = "krenuser"# VM connection details

$VMPassword = "jh87qLXHzFGt6gkb9ukV"$VMHost = "185.182.158.150"

$RemoteDir = "/opt/financial-analysis/reports"$VMPort = "8022"

$VMUser = "krenuser"

Write-Host "Connecting to VM..." -ForegroundColor Yellow$VMPassword = "jh87qLXHzFGt6gkb9ukV"

$RemoteDir = "/opt/financial-analysis/reports"

# Get list of presentation files

$FileListCommand = "ls -1 $RemoteDir/*.pptx 2>/dev/null"Write-Host "Connecting to VM..." -ForegroundColor Yellow

$FileList = plink -ssh -P $VMPort -pw $VMPassword -batch "$VMUser@$VMHost" $FileListCommand

# Get list of presentation files

if (-not $FileList) {$FileListCommand = "ls -1 $RemoteDir/*.pptx 2>/dev/null"

    Write-Host "[FAILED] No presentation files found on VM" -ForegroundColor Red$FileList = plink -ssh -P $VMPort -pw $VMPassword -batch "$VMUser@$VMHost" $FileListCommand

    Write-Host "`nGenerate a presentation first from the dashboard:" -ForegroundColor Yellow

    Write-Host "  -> http://localhost:8050/reports`n" -ForegroundColor Cyanif (-not $FileList) {

    exit 1    Write-Host "✗ No presentation files found on VM" -ForegroundColor Red

}    Write-Host "`nGenerate a presentation first from the dashboard:" -ForegroundColor Yellow

    Write-Host "  → http://localhost:8050/reports`n" -ForegroundColor Cyan

Write-Host "`nFound presentations:" -ForegroundColor Green    exit 1

$Files = $FileList -split "`n" | Where-Object { $_ -match "\.pptx$" }}

$Files | ForEach-Object { Write-Host "  * $_" -ForegroundColor White }

Write-Host "`nFound presentations:" -ForegroundColor Green

Write-Host "`nDownloading presentations..." -ForegroundColor Yellow$Files = $FileList -split "`n" | Where-Object { $_ -match "\.pptx$" }

$Files | ForEach-Object { Write-Host "  • $_" -ForegroundColor White }

$DownloadCount = 0

foreach ($FilePath in $Files) {Write-Host "`nDownloading presentations..." -ForegroundColor Yellow

    $FilePath = $FilePath.Trim()

    if ($FilePath) {$DownloadCount = 0

        $FileName = Split-Path $FilePath -Leafforeach ($FilePath in $Files) {

        $LocalPath = Join-Path $OutputFolder $FileName    $FilePath = $FilePath.Trim()

            if ($FilePath) {

        Write-Host "`n  Downloading: $FileName" -ForegroundColor Cyan        $FileName = Split-Path $FilePath -Leaf

                $LocalPath = Join-Path $OutputFolder $FileName

        # Download file using pscp        

        pscp -P $VMPort -pw $VMPassword -batch "$VMUser@${VMHost}:$FilePath" "$LocalPath" 2>&1 | Out-Null        Write-Host "`n  Downloading: $FileName" -ForegroundColor Cyan

                

        if (Test-Path $LocalPath) {        # Download file using pscp

            $FileSize = (Get-Item $LocalPath).Length / 1KB        pscp -P $VMPort -pw $VMPassword -batch "$VMUser@${VMHost}:$FilePath" "$LocalPath" 2>&1 | Out-Null

            $FileSizeFormatted = "{0:N2}" -f $FileSize        

            Write-Host "  [OK] Downloaded: $FileName ($FileSizeFormatted KB)" -ForegroundColor Green        if (Test-Path $LocalPath) {

            $DownloadCount++            $FileSize = (Get-Item $LocalPath).Length / 1KB

        } else {            $FileSizeStr = $FileSize.ToString('N2')

            Write-Host "  [FAILED] $FileName" -ForegroundColor Red            Write-Host "  [OK] Downloaded: $FileName ($FileSizeStr KB)" -ForegroundColor Green

        }            $DownloadCount++

    }        } else {

}            Write-Host "  [FAILED] $FileName" -ForegroundColor Red

        }

Write-Host "`n============================================" -ForegroundColor Cyan    }

Write-Host "  DOWNLOAD COMPLETE" -ForegroundColor Green}

Write-Host "============================================" -ForegroundColor Cyan

Write-Host "  Total files downloaded: $DownloadCount" -ForegroundColor WhiteWrite-Host "`n============================================" -ForegroundColor Cyan

Write-Host "  Location: $OutputFolder" -ForegroundColor WhiteWrite-Host "  DOWNLOAD COMPLETE" -ForegroundColor Green

Write-Host "============================================`n" -ForegroundColor CyanWrite-Host "============================================" -ForegroundColor Cyan

Write-Host "  Total files downloaded: $DownloadCount" -ForegroundColor White

# Open folderWrite-Host "  Location: $OutputFolder" -ForegroundColor White

Write-Host "Opening folder..." -ForegroundColor YellowWrite-Host "============================================`n" -ForegroundColor Cyan

Start-Process explorer.exe -ArgumentList $OutputFolder

# Open folder

Write-Host "Done!`n" -ForegroundColor GreenWrite-Host "Opening folder..." -ForegroundColor Yellow

Start-Process explorer.exe -ArgumentList $OutputFolder

Write-Host "Done!`n" -ForegroundColor Green
