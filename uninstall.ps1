# ============================================================
#  One-Click App Launcher - uninstall.ps1  (administrator)
#  Called by uninstall.cmd -> run-elevated.vbs
#  Removes the scheduled tasks and the desktop shortcut created by setup.cmd.
# ============================================================

$ErrorActionPreference = 'Continue'

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $root 'apps.json'

# Chinese default name "one-click launch", built from code points (ASCII-safe source).
function Get-DefaultShortcutName {
    return (-join [char[]](0x4E00, 0x952E, 0x542F, 0x52A8))
}

Write-Host "=== uninstall start ==="

if (Test-Path $configPath) {
    $config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

    foreach ($app in @($config.apps)) {
        if ($app.needAdmin -ne $true) { continue }
        $taskId   = if ($app.id) { $app.id } else { $app.name }
        $taskName = "OneClick_$taskId"
        try {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
            Write-Host "removed task: $taskName"
        }
        catch {
            Write-Host "skipped (not found): $taskName"
        }
    }

    $shortcutName = if ($config.shortcutName) { $config.shortcutName } else { Get-DefaultShortcutName }
    $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) "$shortcutName.lnk"
    if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host "removed shortcut: $lnk" }
}

# Safety net: clean up every remaining OneClick_* task (e.g. apps.json was edited later)
Get-ScheduledTask -TaskName 'OneClick_*' -ErrorAction SilentlyContinue | ForEach-Object {
    Unregister-ScheduledTask -TaskName $_.TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "removed leftover task: $($_.TaskName)"
}

Write-Host "=== uninstall done (you may delete the folder itself) ==="
