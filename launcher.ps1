# ============================================================
#  One-Click App Launcher - launcher.ps1
#  Starts the programs listed in apps.json, one after another.
#    * needAdmin = true  -> started through an elevated scheduled task (no UAC popup)
#    * no such task yet  -> falls back to a normal launch (may show UAC)
#  Normally you never edit this file: edit apps.json instead.
#
#  NOTE: keep this file ASCII-only, or save it as UTF-8 *with BOM*.
#        Windows PowerShell 5.1 reads BOM-less UTF-8 files as ANSI and
#        would turn non-ASCII text into garbage.
# ============================================================

$ErrorActionPreference = 'Continue'

$root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $root 'apps.json'

if (-not (Test-Path $configPath)) {
    Write-Host "apps.json not found: $configPath"
    exit 1
}

# Always read the config as UTF8, otherwise non-ASCII names break under PS 5.1.
$config = Get-Content -Path $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Expand-Value([string]$value) {
    if ([string]::IsNullOrWhiteSpace($value)) { return $value }
    return [Environment]::ExpandEnvironmentVariables($value)
}

function Test-TaskExists([string]$taskName) {
    schtasks /Query /TN "$taskName" 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

$apps  = @($config.apps | Where-Object { $_.enabled -ne $false })
$total = $apps.Count
$index = 0

Write-Host "=== One-click launch started ($total apps) ==="

foreach ($app in $apps) {
    $index++
    $name   = $app.name
    $type   = if ($app.type) { $app.type } else { 'exe' }
    $target = Expand-Value $app.target
    $argStr = Expand-Value $app.arguments

    Write-Host "[$index/$total] starting: $name"

    try {
        if ($type -eq 'url' -or $type -eq 'protocol' -or $type -eq 'steam' -or $type -eq 'lnk') {
            # Protocol URL / web URL / shortcut: let the shell open it
            Start-Process $target
        }
        else {
            # Executable
            $taskId   = if ($app.id) { $app.id } else { $name }
            $taskName = "OneClick_$taskId"

            if ($app.needAdmin -eq $true -and (Test-TaskExists $taskName)) {
                # Elevated scheduled task: no UAC popup
                schtasks /Run /TN "$taskName" | Out-Null
            }
            elseif ($argStr) {
                Start-Process -FilePath $target -ArgumentList $argStr
            }
            else {
                Start-Process -FilePath $target
            }
        }
    }
    catch {
        Write-Host "  [FAILED] $name : $($_.Exception.Message)"
    }

    $delay = $app.delayAfterSeconds
    if ($null -eq $delay) { $delay = $config.defaultDelaySeconds }
    if ($null -eq $delay) { $delay = 3 }

    if ($index -lt $total) { Start-Sleep -Seconds $delay }
}

Write-Host "=== All launch commands sent ==="
