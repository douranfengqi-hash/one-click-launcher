' run-hidden.vbs - run a PowerShell script in the same folder without a console window.
' Usage: wscript.exe run-hidden.vbs <script-name.ps1>
' Pure ASCII on purpose: the VBS engine does not handle UTF-8 source well.

Dim fso, sh, dir, scriptArg, scriptPath, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

dir = fso.GetParentFolderName(WScript.ScriptFullName)
If WScript.Arguments.Count > 0 Then
    scriptArg = WScript.Arguments(0)
Else
    scriptArg = "launcher.ps1"
End If

scriptPath = fso.BuildPath(dir, scriptArg)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & scriptPath & """"
sh.Run cmd, 0, False
