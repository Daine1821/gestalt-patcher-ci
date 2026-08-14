@echo off
REM IOKit :product direct read/set — no DYLD, no mad patch
cd /d "%~dp0.."
if "%1"=="set" (
  py -3 scripts\deploy_product_set.py --set
) else if "%1"=="upload" (
  py -3 scripts\deploy_product_set.py --upload-only --binary "%~2"
) else (
  py -3 scripts\deploy_product_set.py --read
)
