<#
  Generates two documents from rules.json. Do not edit the outputs by hand; edit rules.json and
  re-run this script (Test-Rulebook.ps1 fails when they are out of date).
    RULES.md        human reference: every rule with why, examples, fixes, enforcement, evidence
    agent-rules.md  compact do/don't list for coding agents (the agent-context layer)
#>
param([string] $OutDir = $PSScriptRoot)
$ErrorActionPreference = 'Stop'
$book = Get-Content (Join-Path $PSScriptRoot 'rules.json') -Raw | ConvertFrom-Json
New-Item -ItemType Directory $OutDir -Force | Out-Null
$nl = "`n"
function Get-Needs($r) { $q = @($r.requires | Where-Object { $_ }); if ($q) { ($q | ForEach-Object { $book.features.$_ -replace ' \(.*$', '' }) -join ', ' } else { 'any Uno Platform app' } }
$order = @($book.rules | Sort-Object @{ e = { $_.profile -ne 'recommended' } }, @{ e = { -not $_.gating } }, id)

# ---------------------------------------------------------------- RULES.md
$md = [System.Collections.Generic.List[string]]::new()
$md.Add('# Rules'); $md.Add('')
$md.Add('Generated from `rules.json` by `New-RuleDocs.ps1`. Edit the JSON, not this file.'); $md.Add('')
$md.Add('| Rule | uno-lint | Profile | Needs | Status |'); $md.Add('|---|---|---|---|---|')
foreach ($r in $order) {
    $g = if ($r.gating) { $r.profile } else { "$($r.profile), info" }
    $md.Add("| [$($r.id)](#$($r.id.ToLower())) | $(if ($r.unoLint) { $r.unoLint } else { '-' }) | $g | $(Get-Needs $r) | $($r.status) |")
}
foreach ($r in $order) {
    $md.Add(''); $md.Add("## $($r.id)"); $md.Add('')
    $md.Add("$($r.why)"); $md.Add('')
    $md.Add("- **Profile:** $($r.profile)$(if (-not $r.gating) { ' (info, never gating)' })")
    $md.Add("- **Needs:** $(Get-Needs $r)")
    if ($r.notes) { $md.Add("- **Note:** $($r.notes)") }
    $md.Add("- **uno-lint:** $(if ($r.unoLint) { $r.unoLint } else { 'not in uno-lint' })"); $md.Add('')
    $md.Add('Bad:'); $md.Add(''); $md.Add("``````$($r.examples.lang)"); $md.Add($r.examples.bad); $md.Add('```'); $md.Add('')
    $md.Add('Good:'); $md.Add(''); $md.Add("``````$($r.examples.lang)"); $md.Add($r.examples.good); $md.Add('```'); $md.Add('')
    $md.Add('Fix:'); $md.Add('')
    foreach ($k in $r.fix.PSObject.Properties.Name) { $md.Add("- $(if ($k -eq 'default') { 'Default' } else { "With $k" }): $($r.fix.$k)") }
    $md.Add('')
    $md.Add("- **Build layer:** $(if ($r.enforcement.build) { $r.enforcement.build } else { 'none yet' })")
    $md.Add("- **Runtime layer:** $(if ($r.enforcement.runtime) { $r.enforcement.runtime } else { 'none yet' })")
    $md.Add("- **Evidence:** $($r.evidence)")
    $md.Add("- **Differs from uno-lint:** $($r.differsFromUnoLint)")
    $fixtures = (@($r.examples.fixtures) | ForEach-Object { '`' + $_ + '`' }) -join ', '
    $md.Add("- **Fixtures:** $fixtures")
}
Set-Content (Join-Path $OutDir 'RULES.md') (($md -join $nl) + $nl) -NoNewline

# ---------------------------------------------------------------- agent-rules.md
$ag = [System.Collections.Generic.List[string]]::new()
$ag.Add('# Uno Platform code rules for coding agents'); $ag.Add('')
$ag.Add('Generated from `rules.json`. Apply a rule only when the project has what it needs (check `UnoFeatures` in the .csproj or Directory.Build.props). A deliberate exception gets `xaml-lint: allow <rule> - reason` in a comment directly above it.'); $ag.Add('')
foreach ($group in @(@{ name = 'Every project'; rules = @($order | Where-Object { $_.profile -eq 'recommended' }) }, @{ name = 'Strict profile (opt-in)'; rules = @($order | Where-Object { $_.profile -eq 'strict' }) })) {
    $ag.Add("## $($group.name)"); $ag.Add('')
    foreach ($r in $group.rules) {
        $ag.Add("### $($r.id)$(if (@($r.requires | Where-Object { $_ })) { " (needs $(Get-Needs $r))" })"); $ag.Add('')
        $ag.Add($r.why); $ag.Add('')
        $ag.Add("Don't:"); $ag.Add(''); $ag.Add("``````$($r.examples.lang)"); $ag.Add($r.examples.bad); $ag.Add('```'); $ag.Add('')
        $ag.Add('Do:'); $ag.Add(''); $ag.Add("``````$($r.examples.lang)"); $ag.Add($r.examples.good); $ag.Add('```'); $ag.Add('')
        $ag.Add("Fix: $($r.fix.default)")
        foreach ($k in @($r.fix.PSObject.Properties.Name | Where-Object { $_ -ne 'default' })) { $ag.Add(''); $ag.Add("With $($k): $($r.fix.$k)") }
        $ag.Add('')
    }
}
Set-Content (Join-Path $OutDir 'agent-rules.md') (($ag -join $nl).TrimEnd() + $nl) -NoNewline
"Wrote RULES.md and agent-rules.md to $OutDir"
