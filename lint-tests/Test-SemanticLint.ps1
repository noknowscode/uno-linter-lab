<#
  Runs xaml-semantic-lint.ps1 on every fixture case and compares per-rule counts with expected.json
  (rules not listed expect 0). Also runs hook-mode cases. Exit 0 = all pass, 1 = any failure.
    pwsh -File Test-SemanticLint.ps1            # all cases
    pwsh -File Test-SemanticLint.ps1 -Case card # one case
#>
param([string] $Case)
$ErrorActionPreference = 'Stop'
$lint = Join-Path (Split-Path $PSScriptRoot -Parent) 'xaml-semantic-lint.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures'
$fail = 0; $pass = 0

foreach ($dir in Get-ChildItem $fixtures -Directory | Where-Object { -not $Case -or $_.Name -eq $Case }) {
    $expected = Get-Content (Join-Path $dir.FullName 'expected.json') -Raw | ConvertFrom-Json -AsHashtable
    $json = pwsh -NoProfile -File $lint -Path $dir.FullName -Json | Out-String | ConvertFrom-Json
    $actual = @{}
    foreach ($p in $json.counts.PSObject.Properties) { $actual[$p.Name] = [int]$p.Value }
    foreach ($g in $json.findings | Group-Object Rule) { if (-not $actual.ContainsKey($g.Name)) { $actual[$g.Name] = $g.Count } }
    $expSupp = if ($expected.ContainsKey('suppressed')) { $expected['suppressed'] } else { $null }
    $expected.Remove('suppressed')
    $rules = @($actual.Keys) + @($expected.Keys) | Sort-Object -Unique
    $suppDiffs = if ($expSupp) {
        $got = @{}; if ($json.suppressed) { foreach ($p in $json.suppressed.PSObject.Properties) { $got[$p.Name] = [int]$p.Value } }
        foreach ($r in @($got.Keys) + @($expSupp.Keys) | Sort-Object -Unique) {
            $e = [int]$expSupp[$r]; $a = [int]$got[$r]
            if ($e -ne $a) { "    suppressed $r expected $e got $a" }
        }
    }
    $diffs = @($suppDiffs) + @(foreach ($r in $rules) {
        $e = if ($expected.ContainsKey($r)) { [int]$expected[$r] } else { 0 }
        $a = if ($actual.ContainsKey($r)) { $actual[$r] } else { 0 }
        if ($e -ne $a) {
            $where = ($json.findings | Where-Object Rule -eq $r | ForEach-Object { "L$($_.Line) $($_.Detail)" }) -join '; '
            "    $r expected $e got $a  [$where]"
        }
    }) | Where-Object { $_ }
    if ($diffs) { $fail++; "FAIL  $($dir.Name)"; $diffs } else { $pass++; "pass  $($dir.Name)" }
}

# Hook mode: the payload shapes Claude Code sends (Write content, Edit new_string, MultiEdit edits[]).
$hookCases = @(
    @{ name = 'hook-write'; file = 'responsive\Shell.xaml'; input = { param($f) @{ file_path = $f; content = (Get-Content $f -Raw) } }; expect = 'RESPONSIVE' }
    @{ name = 'hook-edit'; file = 'hex\Hex.xaml'; input = { param($f) @{ file_path = $f; old_string = 'x'; new_string = '<TextBlock Foreground="#FF0000" />' } }; expect = 'HEX' }
    @{ name = 'hook-multiedit'; file = 'syncwait\SyncService.cs'; input = { param($f) @{ file_path = $f; edits = @(@{ old_string = 'x'; new_string = 'void A(Task task) => task.Wait();' }) } }; expect = 'SYNCWAIT' }
    @{ name = 'hook-clean'; file = 'clean\MainPage.xaml'; input = { param($f) @{ file_path = $f; content = (Get-Content $f -Raw) } }; expect = $null }
)
if (-not $Case -or $Case -like 'hook*') {
    foreach ($h in $hookCases) {
        $f = Join-Path $fixtures $h.file
        $payload = @{ tool_name = 'Edit'; tool_input = (& $h.input $f) } | ConvertTo-Json -Depth 5 -Compress
        $out = $payload | pwsh -NoProfile -File $lint -Hook | Out-String
        $ok = if ($h.expect) { $out -match "- $($h.expect):" } else { -not $out.Trim() }
        if ($ok) { $pass++; "pass  $($h.name)" } else { $fail++; "FAIL  $($h.name)"; "    expected $(if ($h.expect) { $h.expect } else { 'no output' }), got: $($out.Trim())" }
    }
}

""
"$pass passed, $fail failed"
exit [int]($fail -gt 0)
