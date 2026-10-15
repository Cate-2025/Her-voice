# Downloads and extracts the latest stable Flutter SDK for Windows.
# Safe to re-run: it skips the download if the SDK is already present.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$installRoot = if ($env:FLUTTER_INSTALL_ROOT) { $env:FLUTTER_INSTALL_ROOT } else { 'C:\src' }
$flutterDir = Join-Path $installRoot 'flutter'
$logFile = Join-Path $installRoot 'flutter_install.log'

New-Item -ItemType Directory -Force -Path $installRoot | Out-Null

function Write-Log($message) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $message
    Add-Content -Path $logFile -Value $line
}

if (Test-Path (Join-Path $flutterDir 'bin\flutter.bat')) {
    Write-Log "Flutter already installed at $flutterDir. Nothing to do."
    exit 0
}

Write-Log 'Resolving latest stable Flutter release...'
$releases = Invoke-RestMethod -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json' -TimeoutSec 300
$stable = $releases.releases | Where-Object { $_.hash -eq $releases.current_release.stable } | Select-Object -First 1
if (-not $stable) { throw 'Could not resolve the current stable Flutter release.' }

$archiveUrl = "https://storage.googleapis.com/flutter_infra_release/releases/$($stable.archive)"
$archivePath = Join-Path $installRoot ([System.IO.Path]::GetFileName($stable.archive))

Write-Log "Version $($stable.version) -> $archiveUrl"

if (-not (Test-Path $archivePath)) {
    Write-Log 'Downloading archive (this takes a while)...'
    Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing -TimeoutSec 3600
}
Write-Log ("Downloaded {0:N1} MB" -f ((Get-Item $archivePath).Length / 1MB))

Write-Log 'Extracting...'
Expand-Archive -Path $archivePath -DestinationPath $installRoot -Force
Remove-Item $archivePath -Force

if (-not (Test-Path (Join-Path $flutterDir 'bin\flutter.bat'))) {
    throw "Extraction finished but $flutterDir\bin\flutter.bat was not found."
}

Write-Log 'Extraction complete. Running first-run precache...'
$env:Path = (Join-Path $flutterDir 'bin') + ';' + $env:Path
& (Join-Path $flutterDir 'bin\flutter.bat') precache --android --universal 2>&1 | ForEach-Object { Write-Log $_ }

Write-Log "Flutter SDK ready at $flutterDir"
exit 0
