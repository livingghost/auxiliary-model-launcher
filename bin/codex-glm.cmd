@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\tools\codex\launch.ps1" glm %*
