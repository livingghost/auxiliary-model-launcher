@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\claude\launch.ps1" deepseek %*
