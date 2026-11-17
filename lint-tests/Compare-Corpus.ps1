<#
  Precision check on real apps: runs a baseline lint script and the current one on each app and
  lists every finding that appeared or disappeared (rule, file, line, detail), plus suppression counts.
    pwsh -File Compare-Corpus.ps1 -Baseline ..\xaml-semantic-lint.2026-11-17.bak.ps1 -Apps C:\a, C:\b
#>
param(
    [Parameter(Mandatory)] [string] $Baseline,
    [Parameter(Mandatory)] [string[]] $Apps,
    [string] $Current = (Join-Path (Split-Path $PSScriptRoot -Parent) 'xaml-semantic-lint.ps1')
)
$ErrorActionPreference = 'Stop'
function Get-Run($script, $app) { pwsh -NoProfile -File $script -Path $app -Json | Out-String | ConvertFrom-Json }
function Get-Keyed($run) { $h = @{}; foreach ($f in $run.findings) { $h["$($f.Rule)|$($f.File)|$($f.Line)|$($f.Detail)"] = $f }; $h }

foreach ($app in $Apps) {
    $old = Get-Run $Baseline $app; $new = Get-Run $Current $app
    $ok = Get-Keyed $old; $nk = Get-Keyed $new
    # The baseline cut the first characters of file names under 8.3 paths; match on rule+line+detail+file tail.
    $norm = { param($k) $p = $k -split '\|'; "$($p[0])|$((Split-Path $p[1] -Leaf))|$($p[2])|$($p[3])" }
    $on = @{}; foreach ($k in $ok.Keys) { $on[(& $norm $k)] = $k }
    $nn = @{}; foreach ($k in $nk.Keys) { $nn[(& $norm $k)] = $k }
    $added = @($nn.Keys | Where-Object { -not $on.ContainsKey($_) } | Sort-Object)
    $removed = @($on.Keys | Where-Object { -not $nn.ContainsKey($_) } | Sort-Object)
    $gOld = ($old.counts.PSObject.Properties.Value | Measure-Object -Sum).Sum
    $gNew = ($new.counts.PSObject.Properties.Value | Measure-Object -Sum).Sum
    "=== $app  ($($new.files) files)  gating $gOld -> $gNew"
    if ($new.suppressed) { "  suppressed: " + (($new.suppressed.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ' ') }
    foreach ($k in $added) { "  + $($nk[$nn[$k]].Rule)  $($nk[$nn[$k]].File):$($nk[$nn[$k]].Line)  $($nk[$nn[$k]].Detail)" }
    foreach ($k in $removed) { "  - $($ok[$on[$k]].Rule)  $($ok[$on[$k]].File):$($ok[$on[$k]].Line)  $($ok[$on[$k]].Detail)" }
}
