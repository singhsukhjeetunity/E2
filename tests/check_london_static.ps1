$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
$seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
function Visit([string]$path) {
    $full=[IO.Path]::GetFullPath($path)
    if(-not $seen.Add($full)){return}
    $text=Get-Content -LiteralPath $full -Raw
    foreach($match in [regex]::Matches($text,'#include\s+"([^"]+)"')) {
        $relative=$match.Groups[1].Value.Replace('\\\\','\')
        Visit (Join-Path (Split-Path $full) $relative)
    }
}
Visit (Join-Path $root 'E2.mq5')
$obsolete=@($seen | Where-Object {$_ -match 'E2ADXBB(Engine|Types|TradePlanner|Recovery|RegimeResearch)\.mqh$'})
if($obsolete.Count){throw "Obsolete active include: $obsolete"}
$config=Get-Content -LiteralPath (Join-Path $root 'include\core\E2Config.mqh') -Raw
$inputs=[regex]::Matches($config,'(?m)^input (?!group\b)').Count
if($inputs -ne 27){throw "Expected 27 inputs, found $inputs"}
if($config -match 'adxbb|hybrid|InpResearch_BB|InpResearch_ADX'){throw 'Obsolete alpha in active config'}
$adapter=Get-Content -LiteralPath (Join-Path $root 'include\time\E2BrokerTimeAdapter.mqh') -Raw
if($adapter -match 'TimeGMT\s*\(|TimeLocal\s*\(|FivePercentOnline|The5ers'){throw 'Broker-time inference/hardcoding found'}
$report=Get-Content -LiteralPath (Join-Path $root 'include\reporting\E2TradeReporter.mqh') -Raw
foreach($schema in @(@('SignalHeader',39),@('TradeHeader',54))){
    $line=($report -split '\r?\n' | Where-Object {$_ -match ("void "+$schema[0])})
    $count=[regex]::Matches($line,'"[^"]+"').Count
    if($count -ne $schema[1]){throw "Incorrect $($schema[0]) width: $count"}
}
$main=Get-Content -LiteralPath (Join-Path $root 'E2.mq5') -Raw
$executor=Get-Content -LiteralPath (Join-Path $root 'include\execution\E2OrderExecutor.mqh') -Raw
$planner=Get-Content -LiteralPath (Join-Path $root 'include\strategy\E2LondonTradePlanner.mqh') -Raw
if($main -notmatch 'E2EnforceWeekendFlat\(\)' -or $executor -notmatch 'm_weekend.IsBlockedAt' -or $planner -notmatch 'm_weekend.IsBlockedAt'){throw 'Weekend gate disconnected'}
Push-Location $root
try {git diff --check;if($LASTEXITCODE -ne 0){throw 'git diff --check failed'}} finally {Pop-Location}
Write-Output "[LRB_STATIC_VERIFY] activeFiles=$($seen.Count), oldAlphaIncludes=0, inputs=$inputs, signalColumns=39, tradeColumns=54, brokerGuessing=0, weekendGates=PASS, diffCheck=PASS"
