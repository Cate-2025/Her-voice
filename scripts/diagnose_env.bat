@echo off
REM HERVOICE environment diagnosis - run in cmd: scripts\diagnose_env.bat
echo === COMSPEC (must be C:\Windows\System32\cmd.exe) ===
echo %COMSPEC%
echo.
echo === JAVA_HOME ===
echo [%JAVA_HOME%]
echo.
echo === java on PATH ===
where java
java -version 2>&1
echo.
echo === gradle wrapper jar (must exist) ===
dir "c:\Users\DELL\Desktop\HER VOICE\mobile_flutter\android\gradle\wrapper"
echo.
echo === Android Studio bundled Java candidates ===
if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" echo FOUND: C:\Program Files\Android\Android Studio\jbr
if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" -version 2>&1
dir "C:\Program Files\Java" 2>NUL
echo.
echo === adb devices ===
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices
pause
