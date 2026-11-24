param(
    [ValidateSet("Debug", "Release")]
    [string]$Config = "Debug",
    [ValidateSet("Build", "Clean")]
    [string]$Target = "Build",
    [switch]$RunAfterBuild
)

$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $rootDir "SmokeTester.dproj"
if (-not $env:BDS) {
    $env:BDS = "C:\Apps\RAD\Studio\23.0"
}
$rsvarsPath = Join-Path $env:BDS "bin\rsvars.bat"

if (-not (Test-Path $rsvarsPath)) {
    Write-Error "RAD Studio environment script not found: $rsvarsPath"
    exit 1
}

if (-not (Test-Path $projectPath)) {
    Write-Error "SmokeTester project not found: $projectPath"
    exit 1
}

$candidateMsBuilds = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    (Join-Path $env:BDS "bin\MSBuild.exe"),
    "msbuild"
)

$msbuild = $null
foreach ($candidate in $candidateMsBuilds) {
    if ($candidate -eq "msbuild") {
        $commandInfo = Get-Command msbuild -ErrorAction SilentlyContinue
        if ($commandInfo) {
            $candidate = $commandInfo.Source
        } else {
            continue
        }
    }

    if (Test-Path $candidate) {
        & $candidate "/nologo" "/version" *> $null
        if ($LASTEXITCODE -eq 0) {
            $msbuild = $candidate
            break
        }
    }
}

if (-not $msbuild) {
    Write-Error "No usable MSBuild.exe found. Install Visual Studio Build Tools or RAD Studio."
    exit 1
}

$exePath = Join-Path $rootDir "Win32\$Config\SmokeTester.exe"
$commandLine = 'call "{0}" >nul && "{1}" "{2}" /t:{3} /p:Config={4} /p:Platform=Win32 /verbosity:minimal' -f `
    $rsvarsPath, $msbuild, $projectPath, $Target, $Config

Write-Host "=== $Target SmokeTester ($Config, Win32) ==="
Write-Host "Project: $projectPath"
Write-Host "MSBuild: $msbuild"
& $env:ComSpec /d /s /c $commandLine
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($RunAfterBuild) {
    if ($Target -ne "Build") {
        Write-Error "RunAfterBuild can only be used with the Build target."
        exit 1
    }
    if (-not (Test-Path $exePath)) {
        Write-Error "Build completed but executable was not found: $exePath"
        exit 1
    }

    Write-Host "Starting $exePath"
    Start-Process -FilePath $exePath -Wait
}

exit 0
