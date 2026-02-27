@echo off
setlocal EnableDelayedExpansion

echo ============================================================
echo   ComfyUI Model Resolver
echo   Checks workflow dependencies and downloads missing models
echo ============================================================
echo.

REM --- Configuration ---
set CONTAINER=comfyui
set MODELS_DIR=/root/ComfyUI/models
set SCRIPTS_DIR=/scripts
set WORKFLOWS_DIR=/root/ComfyUI/user/default/workflows
set BUNDLED_DIR=/bundled-workflows

REM --- Check if container is running ---
docker inspect -f "{{.State.Running}}" %CONTAINER% >nul 2>&1
if errorlevel 1 (
    echo ERROR: ComfyUI container '%CONTAINER%' is not running.
    echo Start it with: docker compose up -d
    echo.
    pause
    exit /b 1
)

REM --- Get workflow path from argument or prompt ---
set WORKFLOW=%~1
if not "%WORKFLOW%"=="" goto :resolve_path

REM --- No argument: list available workflows ---
echo.
echo   [Bundled workflows - shipped with Docker image]
docker exec %CONTAINER% sh -c "ls -1 %BUNDLED_DIR%/*.json 2>/dev/null | xargs -I{} basename {}" 2>nul
echo.

echo   [User workflows - persistent volume]
docker exec %CONTAINER% sh -c "ls -1 %WORKFLOWS_DIR%/*.json 2>/dev/null | xargs -I{} basename {}" 2>nul
echo.

echo   [Local .json files in current directory]
set COUNT=0
for %%f in (*.json) do (
    set /a COUNT+=1
    echo     %%f
)
for %%f in (workflows\*.json) do (
    set /a COUNT+=1
    echo     %%f
)
if !COUNT!==0 echo     (none)
echo.

echo Options:
echo   - Type a filename from above
echo   - Type a full path to any .json file
echo   - Type "all" to resolve ALL bundled workflows
echo.
set /p WORKFLOW="Selection: "

if "%WORKFLOW%"=="" (
    echo No workflow specified. Exiting.
    pause
    exit /b 1
)

REM --- Handle "all" ---
if /i "%WORKFLOW%"=="all" (
    echo.
    echo Resolving all bundled workflows...
    docker exec -it %CONTAINER% sh -c "for wf in %BUNDLED_DIR%/*.json; do echo \"\" && echo \"=== $(basename $wf) ===\" && python3 %SCRIPTS_DIR%/resolve_models.py -w \"$wf\" -m %MODELS_DIR% --auto; done"
    echo.
    pause
    exit /b 0
)

:resolve_path
REM --- If it's a local file, copy it into the container ---
if exist "%WORKFLOW%" (
    echo Copying workflow into container...
    docker cp "%WORKFLOW%" %CONTAINER%:/tmp/_resolve_workflow.json
    set CONTAINER_WORKFLOW=/tmp/_resolve_workflow.json
    goto :run
)

REM --- Check bundled dir ---
docker exec %CONTAINER% test -f "%BUNDLED_DIR%/%WORKFLOW%" >nul 2>&1
if not errorlevel 1 (
    set CONTAINER_WORKFLOW=%BUNDLED_DIR%/%WORKFLOW%
    goto :run
)

REM --- Check workflows dir ---
docker exec %CONTAINER% test -f "%WORKFLOWS_DIR%/%WORKFLOW%" >nul 2>&1
if not errorlevel 1 (
    set CONTAINER_WORKFLOW=%WORKFLOWS_DIR%/%WORKFLOW%
    goto :run
)

REM --- Check if it's already a full container path ---
docker exec %CONTAINER% test -f "%WORKFLOW%" >nul 2>&1
if not errorlevel 1 (
    set CONTAINER_WORKFLOW=%WORKFLOW%
    goto :run
)

echo ERROR: Could not find workflow: %WORKFLOW%
pause
exit /b 1

:run
echo.
echo Resolving models for: %CONTAINER_WORKFLOW%
echo.

docker exec -it %CONTAINER% python3 %SCRIPTS_DIR%/resolve_models.py ^
    --workflow "%CONTAINER_WORKFLOW%" ^
    --models-dir %MODELS_DIR%

echo.
pause
