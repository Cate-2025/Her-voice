# HERVOICE emulator boot helper — run with: powershell -ExecutionPolicy Bypass -File scripts\boot_emulator.ps1
# Uses PowerShell syntax ($env:...) so it works in the VS Code PowerShell terminal.
$ErrorActionPreference = 'Stop'
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:PATH = "$env:PATH;$env:ANDROID_HOME\emulator;$env:ANDROID_HOME\platform-tools"
Write-Host "ANDROID_HOME=$env:ANDROID_HOME"
& "$env:ANDROID_HOME\emulator\emulator.exe" -list-avds
$avd = (& "$env:ANDROID_HOME\emulator\emulator.exe" -list-avds | Select-Object -First 1).Trim()
if ([string]::IsNullOrWhiteSpace($avd)) { throw 'No AVD found. Create one in Android Studio > Device Manager first.' }
Write-Host "Booting $avd ..."
Start-Process -FilePath "$env:ANDROID_HOME\emulator\emulator.exe" -ArgumentList @('-avd', $avd, '-no-snapshot-load')
Write-Host 'Emulator launched. Wait ~60s for the home screen, then run:'
Write-Host '  $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"; $env:PATH += ";$env:ANDROID_HOME\platform-tools"; adb devices'
