@echo off
echo ================================================
echo  ComfyUI - Docker Environment
echo ================================================
echo.

cd /d "%~dp0"

echo Cleaning up any existing containers...
docker compose down 2>nul

REM Build if image doesn't exist yet
docker image inspect jgriffith3433/comfyui-docker:latest >nul 2>&1
if errorlevel 1 (
    echo.
    echo First run - building custom image...
    docker compose build
)

echo.
echo Starting ComfyUI...
echo   (First start will auto-download models for bundled workflows)
echo.
docker compose up -d

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo STARTUP FAILED! See errors above.
    pause
    exit /b 1
)

echo.
echo ================================================
echo  ComfyUI is starting!
echo ================================================
echo.
echo  Web UI / API:  http://localhost:8188
echo  Models dir:    ./data/models/
echo  Output dir:    ./data/output/
echo  Workflows:     ./workflows/ (bundled) + ./data/workflows/ (user)
echo.
echo  To skip model download on next start:
echo    set RESOLVE_MODELS=false ^& start.bat
echo.
echo Showing logs (press Ctrl+C to exit)...
echo.
docker compose logs -f comfyui
