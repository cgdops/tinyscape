@echo off
cd /d "%~dp0"
if exist "builds\windows\TinyScape.exe" (
    start "" "builds\windows\TinyScape.exe"
) else (
    where godot >nul 2>nul
    if errorlevel 1 (
        echo Open project.godot in Godot 4.7.2 and press F6 or F5 to play.
        pause
        exit /b 1
    )
    call godot --path "%~dp0."
)
