@echo off
echo ================================================
echo  ComfyUI GPU - Build and Push to Docker Hub
echo ================================================
echo.

cd /d "%~dp0"

echo Step 1: Building GPU image...
docker compose -f docker-compose.gpu.yml build --no-cache

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo BUILD FAILED! See errors above.
    pause
    exit /b 1
)

echo.
echo Step 2: Pushing to Docker Hub...
echo Image: jgriffith3433/comfyui-docker:gpu
docker compose -f docker-compose.gpu.yml push

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo PUSH FAILED! Make sure you're logged into Docker Hub:
    echo   docker login -u jgriffith3433
    pause
    exit /b 1
)

echo.
echo ================================================
echo  Done! Image pushed: jgriffith3433/comfyui-docker:gpu
echo  Deploy to EC2 with: server-manager.py deploy
echo ================================================
pause
