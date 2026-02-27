@echo off
echo Stopping ComfyUI...
cd /d "%~dp0"
docker compose down
echo Done.
pause
