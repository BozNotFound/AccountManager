@echo off
setlocal
REM ===============================================================
REM  flutter_env.cmd  -  run flutter/dart with this project toolchain
REM
REM  IMPORTANT: run this from a NORMAL terminal (Windows Terminal /
REM  cmd / PowerShell), NOT from inside the WorkBuddy agent. The
REM  agent sandbox blocks opening named pipes, which Dart and
REM  Flutter rely on to spawn child processes, producing
REM  "CreateFile failed 231" / "all pipe instances are busy".
REM
REM  Usage (path may be anywhere):
REM    D:\Tools\WBtemp\Financial\code\tool\flutter_env.cmd pub get
REM    D:\Tools\WBtemp\Financial\code\tool\flutter_env.cmd analyze
REM    D:\Tools\WBtemp\Financial\code\tool\flutter_env.cmd build apk --release
REM    D:\Tools\WBtemp\Financial\code\tool\flutter_env.cmd run
REM ===============================================================

if "%~1"=="" (
  echo Usage: flutter_env.cmd ^<flutter command^>
  echo   e.g. flutter_env.cmd build apk --release
  exit /b 1
)

set "FLUTTER_ROOT=D:\CS\flutter"
set "JAVA_HOME=D:\CS\JDK\jdk-17.0.10"
set "ANDROID_SDK_ROOT=D:\CS\android-sdk"
set "ANDROID_HOME=D:\CS\android-sdk"
set "GRADLE_USER_HOME=D:\CS\gradle"
set "PUB_HOSTED_URL=https://mirrors.cloud.tencent.com/dart-pub"
set "FLUTTER_STORAGE_BASE_URL=https://mirrors.huaweicloud.com/flutter"
set "PATH=%FLUTTER_ROOT%\bin;%JAVA_HOME%\bin;%PATH%"

REM project root = parent of this script's folder (tool/ -> code/)
cd /d "%~dp0.."

echo [flutter_env] cwd    = %CD%
echo [flutter_env] flutter %*
echo.

flutter %*
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (echo [flutter_env] DONE ok) else (echo [flutter_env] FAILED rc=%RC%)
exit /b %RC%
