#Requires -Version 5.1
<#+
.SYNOPSIS
Builds this checkout's ICU4C source for Android through Git Bash.

.DESCRIPTION
Git Bash must use a Windows NDK installation. WSL users should invoke
build-android.sh from WSL and configure a Linux NDK there instead.
#>
[CmdletBinding()]
param(
    [string[]] $Arch = @('x86_64'),
    [int] $ApiLevel = 21,
    [switch] $Clean,
    [string[]] $CleanArch,
    [switch] $Help
)

$ErrorActionPreference = 'Stop'
$bashScript = Join-Path $PSScriptRoot 'build-android.sh'

function Find-GitBash {
    $candidates = @(
        'C:\Program Files\Git\bin\bash.exe',
        'C:\Program Files (x86)\Git\bin\bash.exe'
    )
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
    }
    $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

$bash = Find-GitBash
if (-not $bash) {
    throw 'Git Bash was not found. Install Git for Windows, then re-run this command. For WSL, run ./icu4c/packaging/build-android.sh inside WSL with a Linux NDK installation.'
}

$archList = ($Arch | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) -join ','
if (-not $archList) {
    throw 'At least one -Arch value is required (x86_64 and/or arm64-v8a).'
}

$arguments = @($bashScript, "--arch=$archList", "--api=$ApiLevel")
if ($Clean) { $arguments += '--clean' }
if ($CleanArch -and $CleanArch.Count -gt 0) {
    $cleanList = ($CleanArch | ForEach-Object { "$_".Trim() } | Where-Object { $_ }) -join ','
    if ($cleanList) { $arguments += "--clean-arch=$cleanList" }
}
if ($Help) { $arguments = @($bashScript, '--help') }
Write-Host "Running: $bash $($arguments -join ' ')"
& $bash @arguments
exit $LASTEXITCODE
