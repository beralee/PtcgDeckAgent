@echo off
chcp 65001 >nul 2>&1
REM Parallel evolution training launcher
REM Usage: scripts\run_parallel_evolution.bat [generations] [workers]

setlocal
set GODOT="D:\ai\godot\Godot_v4.6.1-stable_win64_console.exe"
set GENERATIONS=%1
if "%GENERATIONS%"=="" set GENERATIONS=50
set WORKERS=%2
if "%WORKERS%"=="" set WORKERS=10
set /a QUIT_AFTER=%GENERATIONS% * 504
set PROJECT_PATH=D:\ai\code\ptcgtrain

echo ===== Parallel Evolution Training =====
echo Generations: %GENERATIONS%
echo Workers: %WORKERS%
echo Timeout: %QUIT_AFTER%s
echo.

start "Evo-1-Standard-A" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.15 --sigma-m=0.10
start "Evo-2-Standard-B" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.15 --sigma-m=0.10
start "Evo-3-Standard-C" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.15 --sigma-m=0.10
if %WORKERS% LEQ 3 goto :done

start "Evo-4-BigStep-A" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.25 --sigma-m=0.20
start "Evo-5-BigStep-B" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.30 --sigma-m=0.15
if %WORKERS% LEQ 5 goto :done

start "Evo-6-FineTune-A" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.08 --sigma-m=0.05
start "Evo-7-FineTune-B" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.10 --sigma-m=0.08
if %WORKERS% LEQ 7 goto :done

start "Evo-8-WeightOnly" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.35 --sigma-m=0.05
start "Evo-9-MCTSOnly" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.05 --sigma-m=0.25
start "Evo-10-LongGame" %GODOT% --headless --quit-after %QUIT_AFTER% --path %PROJECT_PATH% res://scenes/tuner/TunerRunner.tscn -- --generations=%GENERATIONS% --sigma-w=0.20 --sigma-m=0.15 --max-steps=300

:done
echo.
echo Started %WORKERS% evolution workers
echo Check saved versions after completion:
echo   dir "%%APPDATA%%\Godot\app_userdata\PTCG Train\ai_agents\"
echo.
