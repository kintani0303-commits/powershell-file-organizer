@echo off
title CSV一括結合ツール

echo ==========================================
echo.
echo        CSV一括結合ツール
echo.
echo ==========================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Organize-Files-GUI.ps1"

echo.
pause