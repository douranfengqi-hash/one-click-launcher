' run-elevated.vbs - run a PowerShell script in the same folder with administrator rights.
' A single UAC prompt is expected here (that is the point: only once, at setup time).
' Usage: wscript.exe run-elevated.vbs <script-name.ps1>
' Pure ASCII on purpose: the VBS engine does not handle UTF-8 source well.

Dim fso, sh, dir, scriptArg, scriptPath, app
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

dir = fso.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count > 0 Then
    scriptArg = WScript.Arguments(0)
Else
    scriptArg = "setup-admin.ps1"
End If

scriptPath = fso.BuildPath(dir, scriptArg)
Set app = CreateObject("Shell.Application")
' "runas" verb triggers the single UAC consent prompt; -NoExit keeps the window open.
app.ShellExecute "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -NoExit -File """ & scriptPath & """", dir, "runas", 1
