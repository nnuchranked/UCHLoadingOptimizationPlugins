[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Mod,
    [string]$GamePath,
    [string]$ManagedPath,
    [string]$BepInExCorePath,
    [string]$CompilerPath,
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$RepoRoot = $PSScriptRoot

function Find-Directory([string[]]$Candidates) {
    foreach ($Candidate in $Candidates) {
        if (-not [string]::IsNullOrWhiteSpace($Candidate) -and
            (Test-Path -LiteralPath $Candidate -PathType Container)) {
            return (Resolve-Path -LiteralPath $Candidate).Path
        }
    }
    return $null
}

$ModDirectory = Join-Path $RepoRoot $Mod
if (-not (Test-Path -LiteralPath $ModDirectory -PathType Container)) {
    $Available = @(Get-ChildItem -LiteralPath $RepoRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'Source') } |
        Select-Object -ExpandProperty Name)
    throw "Mod '$Mod' not found. Available mods: $($Available -join ', ')"
}

$SourceDirectory = Join-Path $ModDirectory 'Source'
if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
    throw "Missing Source directory: $SourceDirectory"
}
$Sources = @(Get-ChildItem -LiteralPath $SourceDirectory -Filter '*.cs' -File)
if ($Sources.Count -eq 0) { throw "No .cs files found in $SourceDirectory" }

if ($GamePath) {
    if (-not $ManagedPath) { $ManagedPath = Join-Path $GamePath 'UltimateChickenHorse_Data\Managed' }
    if (-not $BepInExCorePath) { $BepInExCorePath = Join-Path $GamePath 'BepInEx\core' }
}
if (-not $ManagedPath) {
    $ManagedPath = Find-Directory @(
        (Join-Path $RepoRoot 'refs\Managed'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Ultimate Chicken Horse\UltimateChickenHorse_Data\Managed'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\Ultimate Chicken Horse\UltimateChickenHorse_Data\Managed')
    )
} elseif (Test-Path -LiteralPath $ManagedPath -PathType Container) {
    $ManagedPath = (Resolve-Path -LiteralPath $ManagedPath).Path
}
if (-not $BepInExCorePath) {
    $BepInExCorePath = Find-Directory @(
        (Join-Path $RepoRoot 'refs\BepInEx\core'),
        (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\Ultimate Chicken Horse\BepInEx\core'),
        (Join-Path $env:ProgramFiles 'Steam\steamapps\common\Ultimate Chicken Horse\BepInEx\core')
    )
} elseif (Test-Path -LiteralPath $BepInExCorePath -PathType Container) {
    $BepInExCorePath = (Resolve-Path -LiteralPath $BepInExCorePath).Path
}

if (-not $ManagedPath -or -not (Test-Path -LiteralPath (Join-Path $ManagedPath 'Assembly-CSharp.dll') -PathType Leaf)) {
    throw "Game Managed assemblies not found. Pass -GamePath/-ManagedPath or use refs\Managed."
}
if (-not $BepInExCorePath -or -not (Test-Path -LiteralPath (Join-Path $BepInExCorePath 'BepInEx.dll') -PathType Leaf)) {
    throw "BepInEx core assemblies not found. Pass -GamePath/-BepInExCorePath or use refs\BepInEx\core."
}
$HarmonyPath = Join-Path $BepInExCorePath '0Harmony.dll'
if (-not (Test-Path -LiteralPath $HarmonyPath -PathType Leaf)) { throw "Harmony DLL not found: $HarmonyPath" }

if ($CompilerPath) {
    if (-not (Test-Path -LiteralPath $CompilerPath -PathType Leaf)) { throw "Compiler not found: $CompilerPath" }
    $CompilerPath = (Resolve-Path -LiteralPath $CompilerPath).Path
} else {
    foreach ($Candidate in @(
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
        (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
    )) {
        if (Test-Path -LiteralPath $Candidate -PathType Leaf) { $CompilerPath = $Candidate; break }
    }
    if (-not $CompilerPath) {
        $Csc = Get-Command 'csc.exe' -ErrorAction SilentlyContinue
        if ($Csc) { $CompilerPath = $Csc.Source }
    }
    if (-not $CompilerPath) { throw 'csc.exe not found. Install compatible .NET Framework build tools or pass -CompilerPath.' }
}

$OutputDirectory = Join-Path $ModDirectory 'build'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$OutputPath = Join-Path $OutputDirectory ($Mod + '.dll')
$Arguments = @('/nologo','/noconfig','/langversion:5','/nostdlib+','/target:library','/optimize+','/debug-','/warn:4',('/out:"' + $OutputPath + '"'))
foreach ($Reference in Get-ChildItem -LiteralPath $ManagedPath -Filter '*.dll' -File) {
    $Arguments += ('/reference:"' + $Reference.FullName + '"')
}
foreach ($ReferenceName in @('BepInEx.dll','0Harmony.dll')) {
    $Arguments += ('/reference:"' + (Join-Path $BepInExCorePath $ReferenceName) + '"')
}
foreach ($Source in $Sources) { $Arguments += ('"' + $Source.FullName + '"') }

Write-Output "Building $Mod..."
$CompilerOutput = & $CompilerPath $Arguments 2>&1
if ($LASTEXITCODE -ne 0) { throw ("Compilation failed:`n" + ($CompilerOutput -join [Environment]::NewLine)) }
if ($CompilerOutput) { $CompilerOutput | ForEach-Object { Write-Output $_ } }
Write-Output "Build successful: $OutputPath"

if ($Install) {
    if (-not $GamePath) { throw '-Install requires -GamePath.' }
    $Destination = Join-Path $GamePath ('BepInEx\plugins\' + $Mod)
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item -LiteralPath $OutputPath -Destination (Join-Path $Destination ($Mod + '.dll')) -Force
    Write-Output "Installed to: $Destination"
}
