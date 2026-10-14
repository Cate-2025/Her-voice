# HERVOICE one-click launcher (PowerShell).
# Double-click-safe: boot emulator, start backend, run the Flutter app.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\run_all.ps1
$ErrorActionPreference = 'Continue'
$root = 'c:\Users\DELL\Desktop\HER VOICE'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:PATH += ";$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools"

Write-Host '=== 1/3 Emulator ==='
$avd = (& "$env:ANDROID_HOME\emulator\emulator.exe" -list-avds | Select-Object -First 1).Trim()
Write-Host "Booting $avd ..."
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList @('-avd', $avd, '-no-snapshot-load')

Write-Host '=== 2/3 Backend (new window, leave running) ==='
Start-Process powershell -ArgumentList '-NoExit', '-Command', "cd '$root\backend'; `$env:ADMIN_EMAILS='admin@university.example'; `$env:OFFICER_EMAILS='officer@university.example'; node index.js"

Write-Host '=== 3/3 Flutter app (opens in cmd) ==='
Write-Host 'Wait ~60s for the Android home screen, then press any key here.'
Read-Host 'Press ENTER when the emulator shows the home screen'
& "$env:ANDROID_HOME\platform-tools\adb.exe" devices
Start-Process cmd -ArgumentList '/k', "cd /d $root\mobile_flutter && C:\src\flutter\bin\flutter.bat run -d emulator-5554"
Write-Host 'Done. The app builds in the cmd window (first build takes 2-5 min).'
