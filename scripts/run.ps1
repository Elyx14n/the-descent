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

Push-Location -LiteralPath $env:DRAGONRUBY_HOME
try {
    & .\dragonruby.exe $gameDir @args
    $gameExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $gameExitCode
