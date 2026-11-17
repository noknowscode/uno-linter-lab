<#
  Template layer check: generates Uno Platform apps from `dotnet new unoapp` in representative
  configurations and lints each one. A fresh project is what every agent and developer copies
  from, so it should pass the recommended profile.

    pwsh -File Test-Templates.ps1                        # latest Uno.Templates, isolated template store
    pwsh -File Test-Templates.ps1 -TemplateVersion 7.0.22
    pwsh -File Test-Templates.ps1 -Json report.json

  Templates are installed into a private template store (--debug:custom-hive), so the machine's
  installed templates are not changed. Exit 0 = every configuration passes the recommended profile.
#>
param(
    [string] $TemplateVersion,
    [string] $WorkDir = (Join-Path ([IO.Path]::GetTempPath()) 'uno-template-check'),
    [string] $Json
)
$ErrorActionPreference = 'Stop'
$lint = Join-Path (Split-Path $PSScriptRoot -Parent) 'xaml-semantic-lint.ps1'
$hive = Join-Path $WorkDir 'hive'
$apps = Join-Path $WorkDir 'apps'
if (Test-Path $apps) { Remove-Item $apps -Recurse -Force }
New-Item -ItemType Directory $hive, $apps -Force | Out-Null

$pkg = if ($TemplateVersion) { "Uno.Templates::$TemplateVersion" } else { 'Uno.Templates' }
$install = dotnet new install $pkg --force --debug:custom-hive $hive 2>&1 | Out-String
$installed = [regex]::Match($install, 'Uno\.Templates@([\d.]+[\w.-]*)').Groups[1].Value
if (-not $installed) { Write-Error "Could not install $pkg`n$install"; exit 2 }

# Representative configurations: each changes what UI code the template writes.
$configs = [ordered]@{
    'blank'                      = @('-preset', 'blank')
    'recommended'                = @('-preset', 'recommended')
    'recommended-mvvm'           = @('-preset', 'recommended', '-presentation', 'mvvm')
    'recommended-nopattern'      = @('-preset', 'recommended', '-presentation', 'none')
    'recommended-fluent'         = @('-preset', 'recommended', '-theme', 'fluent')
    'recommended-cupertino'      = @('-preset', 'recommended', '-theme', 'cupertino')
    'recommended-simple'         = @('-preset', 'recommended', '-theme', 'simple')
    'recommended-csharpmarkup'   = @('-preset', 'recommended', '-markup', 'csharp')
    'recommended-auth'           = @('-preset', 'recommended', '-auth', 'custom')
    'recommended-auth-mvvm'      = @('-preset', 'recommended', '-auth', 'custom', '-presentation', 'mvvm')
    'recommended-themeservice'   = @('-preset', 'recommended', '-theme-service')
    'blank-toolkit-material-mvux' = @('-preset', 'blank', '-toolkit', '-theme', 'material', '-presentation', 'mvux', '-nav', 'regions')
}

$results = foreach ($name in $configs.Keys) {
    $out = Join-Path $apps $name
    $gen = dotnet new unoapp -o $out -n TemplateApp @($configs[$name]) --debug:custom-hive $hive 2>&1 | Out-String
    if (-not (Test-Path $out)) {
        [pscustomobject]@{ Config = $name; Error = ($gen.Trim() -split "`n" | Select-Object -Last 2) -join ' ' }
        continue
    }
    $rec = pwsh -NoProfile -File $lint -Path $out -Json | Out-String | ConvertFrom-Json
    $str = pwsh -NoProfile -File $lint -Path $out -Json -Strict | Out-String | ConvertFrom-Json
    $sum = { param($j) ($j.counts.PSObject.Properties.Value | Measure-Object -Sum).Sum }
    [pscustomobject]@{
        Config = $name; Files = $rec.files
        Recommended = & $sum $rec; Strict = & $sum $str
        RecommendedFindings = @($rec.findings | ForEach-Object { "$($_.Rule) $($_.File):$($_.Line) $($_.Detail)" })
        StrictFindings = @($str.findings | Where-Object { $_.Rule -ne 'XBINDMODE' } | ForEach-Object { "$($_.Rule) $($_.File):$($_.Line) $($_.Detail)" })
        Error = $null
    }
}

"Uno.Templates $installed, $($configs.Count) configurations"
''
'{0,-30} {1,6} {2,12} {3,7}' -f 'Configuration', 'Files', 'Recommended', 'Strict'
foreach ($r in $results) {
    if ($r.Error) { '{0,-30} generation failed: {1}' -f $r.Config, $r.Error; continue }
    '{0,-30} {1,6} {2,12} {3,7}' -f $r.Config, $r.Files, $r.Recommended, $r.Strict
}
foreach ($r in $results | Where-Object { $_.RecommendedFindings }) {
    ''; "$($r.Config) (recommended):"; $r.RecommendedFindings | ForEach-Object { "  $_" }
}
if ($Json) { $results | ConvertTo-Json -Depth 4 | Set-Content $Json }

$failed = @($results | Where-Object { $_.Error -or $_.Recommended -gt 0 })
exit [int]($failed.Count -gt 0)
