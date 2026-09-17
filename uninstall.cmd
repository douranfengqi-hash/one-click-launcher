@echo off
rem Remove the scheduled tasks and the desktop shortcut created by setup.cmd.
wscript.exe "%~dp0run-elevated.vbs" uninstall.ps1
