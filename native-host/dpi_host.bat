@echo off
rem Launcher Chrome uses to start the native messaging host.
rem Uses PowerShell (built into Windows) - no Python required.
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0dpi_host.ps1"
