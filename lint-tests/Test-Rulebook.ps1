<#
  Keeps rulebook/rules.json honest:
    1. Shape: required fields, unique ids, known profiles and features, referenced fixtures exist.
    2. Coverage: every rule the lint can report has an entry, and every entry is a rule it reports.
    3. Examples: each bad example triggers its rule; each good example does not (strict profile,
       in a project with every feature, so no rule is switched off by context).
    4. Generated docs: rulebook/RULES.md and rulebook/agent-rules.md match New-RuleDocs.ps1 output.
  Exit 0 = all pass, 1 = any failure.
#>
$ErrorActionPreference = 'Stop'
$scripts = Split-Path $PSScriptRoot -Parent
$lint = Join-Path $scripts 'xaml-semantic-lint.ps1'
$book = Get-Content (Join-Path $scripts 'rulebook/rules.json') -Raw | ConvertFrom-Json
$fail = [System.Collections.Generic.List[string]]::new(); $pass = 0
function Assert($ok, $msg) { if ($ok) { $script:pass++ } else { $script:fail.Add($msg) } }

# 1. Shape
$features = @($book.features.PSObject.Properties.Name)
$ids = @($book.rules | ForEach-Object id)
Assert ($ids.Count -eq @($ids | Select-Object -Unique).Count) "duplicate rule ids"
foreach ($r in $book.rules) {
    foreach ($field in 'id', 'status', 'profile', 'title', 'why', 'fix', 'examples', 'enforcement', 'evidence') {
        Assert ($null -ne $r.$field -and "$($r.$field)" -ne '') "$($r.id): missing $field"
    }
    Assert ($r.profile -in 'recommended', 'strict') "$($r.id): profile '$($r.profile)'"
    Assert ($r.status -in 'lab', 'in-uno-lint') "$($r.id): status '$($r.status)'"
    Assert ($r.fix.default) "$($r.id): fix.default missing"
    foreach ($q in @($r.requires)) { if ($q) { Assert ($q -in $features) "$($r.id): unknown feature '$q'" } }
    foreach ($k in $r.fix.PSObject.Properties.Name) { Assert ($k -eq 'default' -or $k -in $features) "$($r.id): fix variant '$k' is not a feature" }
    Assert ($r.examples.lang -in 'xaml', 'cs') "$($r.id): examples.lang"
    foreach ($fx in @($r.examples.fixtures)) { Assert (Test-Path (Join-Path $PSScriptRoot "fixtures/$fx")) "$($r.id): fixture '$fx' not found (run New-Fixtures.ps1)" }
}

# 2. Coverage: rule names the lint emits
$src = Get-Content $lint -Raw
$emitted = @([regex]::Matches($src, "New-Finding\s+'(\w+)'") | ForEach-Object { $_.Groups[1].Value }) + @([regex]::Matches($src, "\`$rule = if \(.*?\) \{ '(\w+)' \} else \{ '(\w+)' \}") | ForEach-Object { $_.Groups[1].Value; $_.Groups[2].Value }) | Sort-Object -Unique
foreach ($e in $emitted) { Assert ($e -in $ids) "lint emits $e but the rulebook has no entry" }
foreach ($i in $ids) { Assert ($i -in $emitted) "rulebook entry $i is never emitted by the lint" }

# 3. Examples
$tmp = Join-Path ([IO.Path]::GetTempPath()) "rulebook-examples-$PID"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
$csproj = '<Project Sdk="Uno.Sdk"><PropertyGroup><UnoFeatures>Material;Toolkit;Navigation;MVUX</UnoFeatures></PropertyGroup></Project>'
$page = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:utu="using:Uno.Toolkit.UI"
      xmlns:uen="using:Uno.Extensions.Navigation.UI">
{0}
</Page>
'@
foreach ($r in $book.rules) {
    foreach ($kind in 'bad', 'good') {
        $dir = Join-Path $tmp "$($r.id)-$kind"
        New-Item -ItemType Directory $dir -Force | Out-Null
        Set-Content (Join-Path $dir 'App.csproj') $csproj
        $body = $r.examples.$kind
        if ($r.examples.lang -eq 'xaml') { Set-Content (Join-Path $dir 'Example.xaml') ($page -f $body) }
        else { Set-Content (Join-Path $dir $(if ($r.examples.file) { $r.examples.file } else { 'Example.cs' })) "namespace App;`n$body" }
        $json = pwsh -NoProfile -File $lint -Path $dir -Json -Strict | Out-String | ConvertFrom-Json
        $n = @($json.findings | Where-Object Rule -eq $r.id).Count
        if ($kind -eq 'bad') { Assert ($n -ge 1) "$($r.id): bad example does not trigger the rule" }
        else { Assert ($n -eq 0) "$($r.id): good example triggers the rule ($n hit(s))" }
    }
}
Remove-Item $tmp -Recurse -Force

# 4. Generated docs are current
$gen = Join-Path ([IO.Path]::GetTempPath()) "rulebook-docs-$PID"
pwsh -NoProfile -File (Join-Path $scripts 'rulebook/New-RuleDocs.ps1') -OutDir $gen | Out-Null
foreach ($doc in 'RULES.md', 'agent-rules.md') {
    $have = Join-Path $scripts "rulebook/$doc"
    $same = (Test-Path $have) -and ((Get-Content $have -Raw) -replace "`r`n", "`n") -eq ((Get-Content (Join-Path $gen $doc) -Raw) -replace "`r`n", "`n")
    Assert $same "rulebook/$doc is out of date: run rulebook/New-RuleDocs.ps1"
}
if (Test-Path $gen) { Remove-Item $gen -Recurse -Force }

$fail | ForEach-Object { "FAIL  $_" }
"$pass checks passed, $($fail.Count) failed"
exit [int]($fail.Count -gt 0)
