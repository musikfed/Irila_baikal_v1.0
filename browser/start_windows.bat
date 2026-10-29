@echo off
setlocal
cd /d "%~dp0.."
where uv >nul 2>nul || (echo uv not found. It should already be installed. & exit /b 1)
if not exist ".venv\Scripts\python.exe" (
    uv venv --python 3.13 .venv || exit /b 1
)
uv pip install --python ".venv\Scripts\python.exe" -r "browser\requirements.txt" || exit /b 1
".venv\Scripts\python.exe" "browser\main.py"
