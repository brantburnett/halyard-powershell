Param(
  [string] $Version,

  [string] $NuGetApiKey
)

$modulePath = Resolve-Path -LiteralPath $PSScriptRoot\..\SpinnakerHalyard
$moduleDefPath = Join-Path $modulePath SpinnakerHalyard.psd1
$moduleDef = Get-Content $moduleDefPath

$moduleDef | ForEach-Object {
  if ($_ -match "^\s*ModuleVersion\s*=\s*'[\d\.]*'") {
    "ModuleVersion = '$Version'"
  } else {
    $_
  }
} | Out-File $moduleDefPath -Force -Encoding utf8 -Width 5000

Publish-Module -Path $modulePath -NuGetApiKey $NuGetApiKey
