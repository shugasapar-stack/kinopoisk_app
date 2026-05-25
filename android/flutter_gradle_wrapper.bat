@echo off
setlocal

set "FLUTTER_ROOT=C:\flutter"
set "DART=%FLUTTER_ROOT%\bin\cache\dart-sdk\bin\dart.exe"
set "FLUTTER_TOOLS_DIR=%FLUTTER_ROOT%\packages\flutter_tools"
set "SNAPSHOT_PATH=%FLUTTER_ROOT%\bin\cache\flutter_tools.snapshot"

"%DART%" --packages="%FLUTTER_TOOLS_DIR%\.dart_tool\package_config.json" "%SNAPSHOT_PATH%" %*
exit /b %ERRORLEVEL%
