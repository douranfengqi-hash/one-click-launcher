@echo off
rem One-time setup: register elevated scheduled tasks and create the desktop shortcut.
wscript.exe "%~dp0run-elevated.vbs" setup-admin.ps1
