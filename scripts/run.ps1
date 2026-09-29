$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:DRAGONRUBY_HOME)) {
    Write-Error 'Set DRAGONRUBY_HOME to your extracted Windows DragonRuby SDK directory.'
    exit 1
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$gameDir = Join-Path $repoRoot 'mygame'
$entryPoint = Join-Path $gameDir 'app/main.rb'
$executable = Join-Path $env:DRAGONRUBY_HOME 'dragonruby.exe'

if (-not (Test-Path -LiteralPath $entryPoint -PathType Leaf)) {
    Write-Error "Game entry point not found: $entryPoint"
    exit 1
}

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    Write-Error "DragonRuby executable not found: $executable"
    exit 1
}

# Expose SDK-relative documentation paths; Ruby LSP indexes only docs/oss.
# A directory junction avoids requiring symlink privileges.
$editorLink = Join-Path $repoRoot '.dragonruby-lsp'
$editorSource = Join-Path $env:DRAGONRUBY_HOME 'docs/oss'
try {
    if (-not (Test-Path -LiteralPath $editorSource -PathType Container)) {
        Write-Warning 'SDK docs/oss is missing; DragonRuby editor indexing is unavailable.'
    } else {
        $editorTarget = (Resolve-Path -LiteralPath $env:DRAGONRUBY_HOME).ProviderPath
        $existingLink = Get-Item -LiteralPath $editorLink -Force -ErrorAction SilentlyContinue
        if ($null -ne $existingLink -and $existingLink.LinkType -notin @('Junction', 'SymbolicLink')) {
            Write-Warning "$editorLink is not a link; leaving it untouched."
        } elseif ($null -eq $existingLink -or $existingLink.Target -ne $editorTarget) {
            if ($null -ne $existingLink) {
                # Delete only the link itself, never recurse into the SDK directory.
                $existingLink.Delete()
            }
            New-Item -ItemType Junction -Path $editorLink -Target $editorTarget | Out-Null
        }
    }
} catch {
    Write-Warning "Could not set up DragonRuby editor indexing; continuing to launch. $_"
}

Push-Location -LiteralPath $env:DRAGONRUBY_HOME
try {
    & .\dragonruby.exe $gameDir @args
    $gameExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $gameExitCode
