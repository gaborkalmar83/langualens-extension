# Builds the zip the Chrome Web Store expects: manifest.json at the root of the
# archive, with documentation and this script left out.
#
#   powershell -ExecutionPolicy Bypass -File package.ps1

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
$version = $manifest.version

$include = @(
  'manifest.json',
  'background.js',
  'content.js',
  'content.css',
  'languages.js',
  'translator.js',
  'popup.html',
  'popup.css',
  'popup.js',
  'icons'
)

$dist = Join-Path $root 'dist'
$stage = Join-Path $dist "stage-$version"
New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

foreach ($item in $include) {
  $src = Join-Path $root $item
  if (-not (Test-Path $src)) { throw "missing from the package: $item" }
  Copy-Item $src (Join-Path $stage $item) -Recurse
}

$zip = Join-Path $dist "langualens-chrome-$version.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip)
Remove-Item -Recurse -Force $stage

$size = [math]::Round((Get-Item $zip).Length / 1KB, 1)
Write-Output "$zip  ($size KB)"
