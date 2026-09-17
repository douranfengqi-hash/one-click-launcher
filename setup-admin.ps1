# ============================================================
#  One-Click App Launcher - setup-admin.ps1  (administrator, run once)
#  Called by setup.cmd -> run-elevated.vbs
#
#  Does two things:
#    1. Registers one elevated scheduled task per app with needAdmin = true
#       (task runs "with highest privileges", so no UAC popup later)
#    2. Creates the desktop shortcut
#
#  Results are written to setup.log next to this file.
#
#  NOTE: keep this file ASCII-only, or save it as UTF-8 *with BOM*.
# ============================================================

$ErrorActionPreference = 'Continue'

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $root 'apps.json'
$logPath    = Join-Path $root 'setup.log'

function Log($msg) {
    ("{0}  {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg) | Out-File -FilePath $logPath -Append -Encoding UTF8
}

function Expand-Value([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $value }
    return [Environment]::ExpandEnvironmentVariables($value)
}

# Default shortcut name = U+4E00 U+952E U+542F U+52A8 (Chinese for "one-click launch"),
# built from code points so this source file can stay pure ASCII.
function Get-DefaultShortcutName {
    return (-join [char[]](0x4E00, 0x952E, 0x542F, 0x52A8))
}

"" | Out-File -FilePath $logPath -Encoding UTF8
Log "=== setup start ==="

if (-not (Test-Path $configPath)) {
    Log "FAIL: apps.json not found"
    Write-Host "apps.json not found. Keep this script and apps.json in the same folder."
    exit 1
}

$config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

# ---------- 1. register elevated scheduled tasks ----------
foreach ($app in @($config.apps)) {
    if ($app.needAdmin -ne $true) { continue }

    $taskId   = if ($app.id) { $app.id } else { $app.name }
    $taskName = "OneClick_$taskId"
    $exe      = Expand-Value $app.target
    $argStr   = Expand-Value $app.arguments

    try {
        if (-not (Test-Path $exe)) { throw "executable not found: $exe" }

        $actionArgs = @{ Execute = $exe }
        if ($argStr) { $actionArgs.Argument = $argStr }
        if ($app.workingDirectory) { $actionArgs.WorkingDirectory = Expand-Value $app.workingDirectory }

        $action  = New-ScheduledTaskAction @actionArgs
        # Trigger in the past on purpose: the task never runs by itself,
        # it can only be fired manually by launcher.ps1 (schtasks /Run).
        $trigger = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddDays(-365))

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -RunLevel Highest -Force -ErrorAction Stop | Out-Null

        Log "OK: scheduled task $taskName  ->  $exe"
    }
    catch {
        Log "FAIL $taskName : $($_.Exception.Message)"
    }
}

# ---------- 2. create the desktop shortcut ----------
try {
    $shortcutName = if ($config.shortcutName) { $config.shortcutName } else { Get-DefaultShortcutName }
    $desktop      = [Environment]::GetFolderPath('Desktop')

    $ws = New-Object -ComObject WScript.Shell
    $sc = $ws.CreateShortcut((Join-Path $desktop "$shortcutName.lnk"))
    $sc.TargetPath       = "$env:SystemRoot\System32\wscript.exe"
    $sc.Arguments        = '"{0}" launcher.ps1' -f (Join-Path $root 'run-hidden.vbs')
    $sc.WorkingDirectory = $root

    $icon = Expand-Value $config.iconSource
    if ($icon -and (Test-Path ($icon -split ',')[0])) { $sc.IconLocation = $icon }

    $sc.Description = "One-click launcher: opens every app listed in apps.json"
    $sc.Save()
    Log "OK: desktop shortcut -> $desktop\$shortcutName.lnk"
}
catch {
    Log "FAIL shortcut: $($_.Exception.Message)"
}

Log "=== setup end ==="
Get-Content $logPath -Encoding UTF8 | Write-Host
Write-Host ""
Write-Host "If every line above says OK, close this window and double-click the desktop shortcut."
