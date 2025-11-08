#!/usr/bin/env pwsh
param(
    [string]$ZenohSource = "../zenoh",
    [ValidateSet('Release','Debug')]
    [string]$Configuration = 'Release'
)

if (-not (Test-Path $ZenohSource)) {
    Write-Error "Zenoh source not found at $ZenohSource"
    exit 1
}

$buildRoot = "build/windows"
$outDir = "native/windows/x64"
Remove-Item $buildRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $buildRoot, $outDir | Out-Null

cmake -S $ZenohSource -B $buildRoot -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=$Configuration
cmake --build $buildRoot --config $Configuration --target zenoh-ffi

Copy-Item "$buildRoot/$Configuration/zenoh-ffi.dll" "$outDir/zenoh.dll" -Force
Write-Host "Shared library ready at $outDir/zenoh.dll"
