# uno-linter-lab

A semantic lint for Uno Platform apps, written in PowerShell. It flags XAML and C# that hand-builds something the framework already provides (a rounded `Border` drawn as a card, a hex colour outside the theme, a WinUI `AdaptiveTrigger` in an app that has `{utu:Responsive}`) and names what to use instead.

This is the lab. Every rule is tried here first, backed by fixture tests and a run on real apps, before it is proposed for [uno-lint](https://github.com/unoplatform/studio/tree/main/tools/uno-lint), the C# linter for Uno Platform users.

## Run it

PowerShell 7 or later, on Windows, macOS or Linux.

```powershell
pwsh -File xaml-semantic-lint.ps1 -Path ./MyUnoApp           # recommended profile, text report
pwsh -File xaml-semantic-lint.ps1 -Path ./MyUnoApp -Strict   # adds the opinionated rules
pwsh -File xaml-semantic-lint.ps1 -Path ./MyUnoApp -Json     # JSON report
```

Exit codes: `0` clean, `1` at least one gating finding, `2` bad input. `bin`, `obj`, `.git`, `node_modules` and generated `*.g.cs` files are never read. Folders named `Dev`, `Harness`, `Probe(s)` or `Test(s)` are skipped unless `-IncludeDev`.

### As an agent hook

`-Hook` reads an edit payload as JSON on stdin (`tool_input.file_path` plus `content`, `new_string`, or `edits[].new_string`) and reports only findings inside the text the edit added. It always exits `0`, so it never blocks an edit; the findings go back to the agent as context, with the fix for each rule. Wire it as a post-edit hook for `*.xaml` and `*.cs` in any coding agent that supports that payload shape. Add `-Strict` for the strict profile.

## It reads your project first

Each file is linted against the features its project references. The lint reads the nearest `.csproj` above the file, every `Directory.Build.props` and `Directory.Packages.props` from there up, the project's `App.xaml`, and the file's own `xmlns` declarations. It looks for `UnoFeatures` values and package references:

| Feature | Detected from | What changes |
|---|---|---|
| Uno Toolkit | `Toolkit` feature, `Uno.Toolkit*` package, `using:Uno.Toolkit.UI` | CARD, BACKBAR and the AdaptiveTrigger check run only with Toolkit; fix texts suggest `utu:` controls only with Toolkit |
| Uno.Themes | `Material`, `Cupertino` or `Simple*` feature, `Uno.Themes`/`Uno.Material` packages, a theme in `App.xaml` | SPACING and RADIUS (which suggest `Space*`/`Radius*` tokens) run only with a theme; HEX advice names Material role brushes only with Material |
| Navigation | `Navigation` feature, `Uno.Extensions.Navigation` | OVERLAY suggests a `!Route` flyout only with Navigation |
| MVUX | `MVUX` feature, `Uno.Extensions.Reactive` | BINDVALUE runs only in MVUX projects |

A plain WinUI/Fluent Uno Platform app is never told to use controls or tokens it does not have. Projects with `<UseMaui>true</UseMaui>` and XAML files whose root namespace is not WinUI (for example .NET MAUI controls embedded in an app) are skipped.

## Profiles

**Recommended** (default): rules that hold for any Uno Platform app.

**Strict** (`-Strict`): adds the opinionated rules CARD, BACKBAR, CODEBEHIND, OVERLAY, SPACING and RADIUS, and limits colours to the palette override file (a colour in `ThemeDictionaries` counts as a hit).

Every rule, with its reason, bad and good example, fixes per project feature, evidence and how it maps to uno-lint, is in [rulebook/RULES.md](rulebook/RULES.md).

## The rulebook

`rulebook/rules.json` is the single source for each rule. The lint reads each rule's profile, the features it needs, its title and its fix text from it; the script itself only holds detection. Two documents are generated from it with `rulebook/New-RuleDocs.ps1`:

- `RULES.md`: the human reference.
- `agent-rules.md`: a compact do/don't list for coding agents, for skills, agent instructions or MCP usage rules.

Each rule's bad and good example is tested: the bad one must trigger the rule and the good one must not. `lint-tests/Test-Rulebook.ps1` checks that, plus the rulebook's shape, that the lint and the rulebook list the same rules, and that the generated documents are current.
## Suppressing a hit

A deliberate exception gets an allow comment with a reason:

```xml
<!-- xaml-lint: allow icon - illustration, not an icon -->
<Canvas>
  <Path Data="M0,0 L10,10 Z" />
  <Path Data="M4,4 L6,6 Z" />
</Canvas>
```

```csharp
Color mark = Colors.Red; // xaml-lint: allow cscolor - logo mark, fixed in both themes
```

- In XAML, the comment covers the element directly below it, children included, and nothing after it.
- In C#, the comment goes on the same line or in the comment lines directly above.
- `uno-lint:` works as a prefix too, and `allow all` covers every rule.
- AdaptiveTrigger hits cannot be suppressed.
- Every suppressed hit is counted in the report's Supp column, so exceptions stay visible.

## Tests

```powershell
pwsh -File lint-tests/New-Fixtures.ps1        # rewrite the fixture tree
pwsh -File lint-tests/Test-SemanticLint.ps1   # every fixture case and the hook payload shapes
pwsh -File lint-tests/Test-Rulebook.ps1       # rulebook shape, coverage, examples, generated docs
pwsh -File lint-tests/Test-Templates.ps1      # lint fresh `dotnet new unoapp` projects
```

Each folder under `lint-tests/fixtures/` holds source files and an `expected.json` with the exact count per rule. Unlisted rules expect 0; `suppressed` checks the Supp counts, `lines` checks reported line numbers, and `"profile": "recommended"` runs a case without `-Strict`. The `corpus-*` and `template-*` cases reproduce false positives found in Uno Platform's own apps, samples and templates.

`Test-Templates.ps1` installs the latest Uno.Templates into a private template store, generates 12 configurations (presets, MVUX/MVVM/none, XAML/C# Markup, every theme, authentication, Toolkit) and lints each. A fresh project is what everyone copies from, so every configuration must pass the recommended profile. CI runs it every Monday so a template release that teaches a flagged pattern shows up within a week.

CI runs the lint tests on Windows, macOS and Linux, and the rulebook and template checks on Linux.

`Compare-Corpus.ps1` runs two versions of the lint on real apps and lists every finding that appeared or disappeared, which is how a rule change is checked for false positives before it moves on.

## How a rule gets in

1. Add the rule to `rulebook/rules.json` with a bad and a good example, and its detection to `xaml-semantic-lint.ps1`.
2. Add fixtures: a hit, a near miss that must stay clean, and a suppressed hit.
3. Run `Compare-Corpus.ps1` on real apps and explain every added or removed finding; record it in the rule's `evidence`.
4. Regenerate the docs, run all three test scripts.
5. Only then propose it for uno-lint.