param([string]$Device = 'RF8T1051S0V')
$ErrorActionPreference = 'Stop'
$adb = 'D:\dev-tools\android-sdk\platform-tools\adb.exe'
$package = 'ru.cashbackguide.balance_app'
$projectRoot = Split-Path -Parent $PSScriptRoot
$context = Get-Content (Join-Path $projectRoot 'PROJECT_CONTEXT.md')
$fixtureNames = @($context | ForEach-Object { if ($_ -match '^\d\. `([^`]+\.jpg)`$') { $Matches[1] } })
if ($fixtureNames.Count -ne 5) { throw 'Expected five private source fixtures in project context.' }
& $adb -s $Device shell run-as $package mkdir -p files/ocr-fixtures
if ($LASTEXITCODE -ne 0) { throw 'Install the debug application and authorize USB debugging first.' }
for ($i = 0; $i -lt $fixtureNames.Count; $i++) {
    $source = Join-Path 'D:\downloads-firefox' $fixtureNames[$i]
    if (-not (Test-Path -LiteralPath $source)) { throw "Private fixture $($i + 1) is not available." }
    $remote = "/data/local/tmp/cashback-ocr-fixture-$($i + 1).jpg"
    & $adb -s $Device push $source $remote 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not transfer private fixture $($i + 1)." }
    & $adb -s $Device shell run-as $package cp $remote "files/ocr-fixtures/$($i + 1).jpg"
    if ($LASTEXITCODE -ne 0) { throw "Could not prepare private fixture $($i + 1)." }
    $remoteHash = (& $adb -s $Device shell run-as $package sha256sum "files/ocr-fixtures/$($i + 1).jpg") -split '\s+' | Select-Object -First 1
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ($remoteHash -ne $sourceHash) { throw "Private fixture $($i + 1) failed integrity validation." }
    & $adb -s $Device shell rm $remote
    Write-Output "Prepared private fixture $($i + 1)."
}
