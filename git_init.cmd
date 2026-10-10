@echo off
setlocal enabledelayedexpansion
rem ============================================================
rem  git_init.cmd - one-click Git setup for this project
rem
rem  Repository root = this folder (the Flutter project root).
rem  NOTE: ../docs, ../keystore and ../check_and_build.* are
rem  OUTSIDE this repository and are not tracked here.
rem
rem  ASCII-only on purpose: cmd.exe mis-parses UTF-8 batch files.
rem  No goto/labels on purpose: cmd.exe also mis-parses LF-only
rem  files at jump targets. All exits use inline "pause & exit /b".
rem
rem  Usage:
rem    git_init.cmd              double-click friendly (waits at end)
rem    git_init.cmd --no-pause   no trailing pause (for scripting)
rem
rem  This script NEVER pushes. It only: init -> add -> guard -> report.
rem  See ../docs/ Git guide (Chinese) for the GitHub remote steps.
rem ============================================================

cd /d "%~dp0"
echo.
echo ==================================================
echo   Git setup - ledger project (repo root = code\)
echo   root: %CD%
echo ==================================================

echo.
echo [1/6] check git
where git >nul 2>&1
if errorlevel 1 (
  echo   [FAIL] git not found in PATH.
  echo          Install Git for Windows: https://git-scm.com/download/win
  echo. & pause & exit /b 1
)
for /f "delims=" %%v in ('git --version') do echo   %%v

echo.
echo [2/6] init repository
if exist ".git\" (
  echo   [SKIP] a repository already exists here, keeping it.
) else (
  git init -b main >nul 2>&1
  if errorlevel 1 (
    echo   [INFO] older git detected, falling back to init + branch -M main
    git init >nul
    git branch -M main
  )
  echo   [OK] repository created, default branch: main
)

echo.
echo [3/6] check identity
git config core.quotepath false
git config --get user.name >nul 2>&1
if errorlevel 1 (
  echo   [MISS] user.name is not configured. Run these two first:
  echo            git config --global user.name  "Your Name"
  echo            git config --global user.email "you@example.com"
  echo. & pause & exit /b 1
)
git config --get user.email >nul 2>&1
if errorlevel 1 (
  echo   [MISS] user.email is not configured. Run these two first:
  echo            git config --global user.name  "Your Name"
  echo            git config --global user.email "you@example.com"
  echo. & pause & exit /b 1
)
for /f "delims=" %%n in ('git config --get user.name') do echo   user.name  = %%n
for /f "delims=" %%e in ('git config --get user.email') do echo   user.email = %%e

echo.
echo [4/6] stage files
git add -A
if errorlevel 1 (
  echo   [FAIL] git add failed.
  echo. & pause & exit /b 1
)
echo   [OK] staged.

echo.
echo [5/6] secret-file guard
rem Any hit here means a file that must never reach a remote got tracked.
set "LEAK=0"
for /f "delims=" %%f in ('git ls-files ^| findstr /i "key.properties local.properties keystore/ SIGNING-README .jks"') do (
  echo   [DANGER] must NOT be committed: %%f
  set "LEAK=1"
)
if "!LEAK!"=="1" (
  echo.
  echo   Fix:  git rm --cached ^<that-file^>   then run this script again.
  echo   Aborted - nothing was committed.
  echo. & pause & exit /b 1
)
echo   [OK] no secret file is tracked.

echo.
echo [6/6] summary
git status --short
echo.
echo   staged file count:
git diff --cached --name-only | find /c /v ""

echo.
echo ==================================================
echo   Ready. Create the first commit with:
echo     git commit -m "chore: init repo (M1-M7 source, docs, build script)"
echo.
echo   Then connect your GitHub private repo:
echo     git remote add origin https://github.com/^<you^>/^<repo^>.git
echo     git branch -M main
echo     git push -u origin main
echo.
echo   Full guide: ../docs/  (Git usage guide, in Chinese)
echo ==================================================
echo.
if /i not "%~1"=="--no-pause" pause
endlocal
