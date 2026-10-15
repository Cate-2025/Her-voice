@echo off
REM HERVOICE full-app launcher for cmd.exe - run: scripts\run_app.bat
REM Fixes broken COMSPEC/JAVA_HOME, boots emulator, starts backend, runs Flutter.
setlocal
set COMSPEC=C:\Windows\System32\cmd.exe
if not exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
  echo WARNING: Android Studio JBR not found, keeping current JAVA_HOME=[%JAVA_HOME%]
) else (
  set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
)
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set PATH=%PATH%;%ANDROID_HOME%\emulator;%ANDROID_HOME%\platform-tools
echo COMSPEC=%COMSPEC%
echo JAVA_HOME=%JAVA_HOME%
"%JAVA_HOME%\bin\java.exe" -version
echo.
echo === Booting emulator ===
for /f "delims=" %%A in ('"%ANDROID_HOME%\emulator\emulator.exe" -list-avds') do set AVD=%%A & goto gotavd
:gotavd
echo AVD=%AVD%
start "HERVOICE emulator" "%ANDROID_HOME%\emulator\emulator.exe" -avd %AVD% -no-snapshot-load
echo.
echo === Starting backend (new window, leave running) ===
start "HERVOICE backend" cmd /k "cd /d c:\Users\DELL\Desktop\HER VOICE\backend && set ADMIN_EMAILS=admin@university.example && set OFFICER_EMAILS=officer@university.example && node index.js"
echo.
echo Wait ~60 seconds for the Android home screen, then press any key to build the app...
pause >nul
"%ANDROID_HOME%\platform-tools\adb.exe" devices
cd /d c:\Users\DELL\Desktop\HER VOICE\mobile_flutter
C:\src\flutter\bin\flutter.bat run -d emulator-5554
