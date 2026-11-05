<#
.SYNOPSIS
    Installs (or updates) the C# guardrails into your global Claude Code config.

.DESCRIPTION
    - Copies agents, standards and hooks into <ClaudeHome>.
    - Adds or replaces a marked C# section in <ClaudeHome>\CLAUDE.md with your level and base branch.
    - Merges permissions, hooks and env into <ClaudeHome>\settings.json without removing your own settings.
    - Backs up CLAUDE.md and settings.json before changing them.
    Safe to run again: it updates in place instead of duplicating.

.EXAMPLE
    .\install.ps1 -Level mid
.EXAMPLE
    .\install.ps1 -Level senior -BaseBranch develop -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('junior', 'mid', 'senior')]
    [string]$Level,

    [string]$BaseBranch = 'dev',

    [string]$ClaudeHome = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }),

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$ourHookScripts = @('dotnet-guard.ps1', 'commit-guard.ps1')

function Render([string]$text) {
    $text.Replace('{{LEVEL}}', $Level).
          Replace('{{BASE_BRANCH}}', $BaseBranch).
          Replace('{{CLAUDE_HOME}}', ($ClaudeHome -replace '\\', '/'))
}

function Read-Utf8([string]$path) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) }

function Write-Utf8([string]$path, [string]$text) {
    if ($DryRun) { Write-Host "  [dry-run] would write $path"; return }
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
}

function Backup([string]$path) {
    if ((Test-Path -LiteralPath $path) -and -not $DryRun) {
        Copy-Item -LiteralPath $path "$path.bak-$stamp"
        Write-Host "  backup: $path.bak-$stamp"
    }
}

function Ensure-Property($obj, [string]$name, $default) {
    if (-not ($obj.PSObject.Properties.Name -contains $name)) {
        $obj | Add-Member -NotePropertyName $name -NotePropertyValue $default
    }
    return $obj.$name
}

function Set-Property($obj, [string]$name, $value) {
    if ($obj.PSObject.Properties.Name -contains $name) { $obj.$name = $value }
    else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value }
}

function Test-OurHookEntry($entry) {
    foreach ($h in @($entry.hooks)) {
        foreach ($name in $ourHookScripts) {
            if ([string]$h.command -like "*$name*") { return $true }
        }
    }
    return $false
}

Write-Host "Installing C# guardrails -> $ClaudeHome (level: $Level, base branch: $BaseBranch)"
if (-not $DryRun) { New-Item -ItemType Directory -Force $ClaudeHome | Out-Null }

# 1. Agents, standards, hooks
foreach ($dir in 'agents', 'standards', 'hooks') {
    $dest = Join-Path $ClaudeHome $dir
    if (-not $DryRun) { New-Item -ItemType Directory -Force $dest | Out-Null }
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $src $dir) -File) {
        $target = Join-Path $dest $file.Name
        Write-Host "  $dir/$($file.Name)"
        if ($file.Extension -eq '.md') {
            Write-Utf8 $target (Render (Read-Utf8 $file.FullName))
        } elseif (-not $DryRun) {
            Copy-Item -LiteralPath $file.FullName $target -Force
        }
    }
}

# 2. CLAUDE.md: replace our marked block, or append it
$claudeMd = Join-Path $ClaudeHome 'CLAUDE.md'
$startMark = '<!-- csharp-guardrails:start -->'
$endMark = '<!-- csharp-guardrails:end -->'
$block = $startMark + "`n" + (Render (Read-Utf8 (Join-Path $src 'CLAUDE.snippet.md'))).Trim() + "`n" + $endMark
$existing = if (Test-Path -LiteralPath $claudeMd) { Read-Utf8 $claudeMd } else { '' }
$pattern = [regex]::Escape($startMark) + '[\s\S]*?' + [regex]::Escape($endMark)
if ([regex]::IsMatch($existing, $pattern)) {
    $newMd = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $block })
} elseif ($existing.Trim()) {
    $newMd = $existing.TrimEnd() + "`n`n" + $block + "`n"
} else {
    $newMd = $block + "`n"
}
Write-Host "  CLAUDE.md (C# section)"
Backup $claudeMd
Write-Utf8 $claudeMd $newMd

# 3. settings.json: merge, never remove the user's own entries
$settingsPath = Join-Path $ClaudeHome 'settings.json'
$snippet = (Render (Read-Utf8 (Join-Path $src 'settings.snippet.json'))) | ConvertFrom-Json
$settings = $null
if (Test-Path -LiteralPath $settingsPath) {
    $raw = Read-Utf8 $settingsPath
    if ($raw.Trim()) {
        try { $settings = $raw | ConvertFrom-Json }
        catch { throw "Could not parse $settingsPath as JSON. Fix it, then run the installer again. ($_)" }
    }
}
if (-not $settings) { $settings = New-Object PSObject }

$envBlock = Ensure-Property $settings 'env' (New-Object PSObject)
Set-Property $envBlock 'CLAUDE_BASE_BRANCH' $BaseBranch

# Simple top-level settings from the snippet (e.g. attribution off) are set as-is.
foreach ($prop in $snippet.PSObject.Properties) {
    if ($prop.Name -notin 'permissions', 'hooks', 'env') { Set-Property $settings $prop.Name $prop.Value }
}

$perm = Ensure-Property $settings 'permissions' (New-Object PSObject)
foreach ($kind in $snippet.permissions.PSObject.Properties.Name) {
    $current = @()
    if ($perm.PSObject.Properties.Name -contains $kind) { $current = @($perm.$kind) }
    $merged = @(@($current) + @($snippet.permissions.$kind) | Where-Object { $_ } | Select-Object -Unique)
    Set-Property $perm $kind $merged
}

$hooks = Ensure-Property $settings 'hooks' (New-Object PSObject)
foreach ($evt in $snippet.hooks.PSObject.Properties) {
    $current = @()
    if ($hooks.PSObject.Properties.Name -contains $evt.Name) { $current = @($hooks.($evt.Name)) }
    $kept = @($current | Where-Object { $_ -and -not (Test-OurHookEntry $_) })
    Set-Property $hooks $evt.Name @($kept + @($evt.Value))
}

Write-Host "  settings.json (permissions, hooks, env)"
Backup $settingsPath
Write-Utf8 $settingsPath (ConvertTo-Json -InputObject $settings -Depth 32)

Write-Host ""
Write-Host "Done. Restart Claude Code so it picks up the new agents, hooks and settings."
Write-Host "Per C# repo: copy templates\.editorconfig to the repo root, and optionally git-hooks\pre-commit and git-hooks\commit-msg (see README)."
