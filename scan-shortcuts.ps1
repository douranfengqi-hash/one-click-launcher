# ============================================================
#  One-Click App Launcher - scan-shortcuts.ps1
#  Scans the Desktop + Public Desktop for shortcuts (.lnk / .url),
#  resolves their real targets, and writes a draft config
#  (apps.suggested.json) that you can rename to apps.json.
#
#  Usage:  powershell -ExecutionPolicy Bypass -File .\scan-shortcuts.ps1
#
#  needAdmin is only a rough guess (target lives under Program Files).
#  Confirm against reality: does the app show a UAC prompt when started?
#
#  NOTE: keep this file ASCII-only, or save it as UTF-8 *with BOM*.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path $root 'apps.suggested.json'

$ws = New-Object -ComObject WScript.Shell

$desktops = @([Environment]::GetFolderPath('Desktop'), 'C:\Users\Public\Desktop')
$items = @()

function To-Token([string]$path) {
    # Replace well-known system folders with environment variables so the
    # config stays portable across machines.
    if (-not $path) { return $path }
    foreach ($pair in @(
        @{ Env = '%ProgramFiles(x86)%'; Real = ${env:ProgramFiles(x86)} },
        @{ Env = '%ProgramFiles%';       Real = $env:ProgramFiles },
        @{ Env = '%USERPROFILE%';        Real = $env:USERPROFILE }
    )) {
        if ($pair.Real -and $path.StartsWith($pair.Real, [StringComparison]::OrdinalIgnoreCase)) {
            return ($pair.Env + $path.Substring($pair.Real.Length))
        }
    }
    return $path
}

foreach ($desktop in $desktops) {
    Get-ChildItem -Path (Join-Path $desktop '*') -Include *.lnk, *.url -File | ForEach-Object {
        $file   = $_
        $name   = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $target = ''
        $type   = 'exe'
        $args   = ''

        if ($file.Extension -ieq '.lnk') {
            $lnk    = $ws.CreateShortcut($file.FullName)
            $target = $lnk.TargetPath
            $args   = $lnk.Arguments
            if (-not $target) { $target = $file.FullName; $type = 'lnk' }
        }
        else {
            # .url files are plain text: read the URL= line (may be a protocol
            # such as steam://)
            $url = (Select-String -Path $file.FullName -Pattern '^URL=(.+)$' |
                    Select-Object -First 1).Matches.Groups[1].Value
            $target = $url
            $type   = 'url'
        }

        $needAdmin = $false
        if ($type -eq 'exe' -and $target -match '\\Program Files( \(x86\))?\\') { $needAdmin = $true }

        $items += [PSCustomObject]@{
            name              = $name
            id                = ($name -replace '[^\w\u4e00-\u9fa5]', '')
            type              = $type
            target            = (To-Token $target)
            arguments         = $args
            needAdmin         = $needAdmin
            delayAfterSeconds = 3
            enabled           = $true
        }
    }
}

$config = [PSCustomObject]@{
    shortcutName        = (-join [char[]](0x4E00, 0x952E, 0x542F, 0x52A8))
    iconSource          = ''
    defaultDelaySeconds = 3
    apps                = $items
}

$config | ConvertTo-Json -Depth 6 | Out-File -FilePath $out -Encoding UTF8

Write-Host "Scanned $($items.Count) shortcuts. Draft written to: $out"
Write-Host ""
Write-Host "Reminder: needAdmin is a rough guess (target under Program Files)."
Write-Host "          Confirm by observing whether the app asks for UAC, then rename"
Write-Host "          the draft to apps.json and adjust as needed."
Write-Host ""
$items | Select-Object name, type, target, needAdmin | Format-Table -AutoSize
