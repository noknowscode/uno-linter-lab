# uno-linter-lab

A semantic lint for Uno Platform apps, written in PowerShell. It flags XAML and C# that hand-builds something the framework already provides (a rounded `Border` drawn as a card, a hex colour outside the palette, a WinUI `AdaptiveTrigger` where `{utu:Responsive}` belongs) and names what to use instead.

This is the lab. Every rule is tried here first, backed by fixture tests and a run on real apps, before it is proposed for [uno-lint](https://github.com/unoplatform/studio/tree/main/tools/uno-lint), the C# linter for Uno Platform users.

## Run it

PowerShell 7+.

```powershell
pwsh -File xaml-semantic-lint.ps1 -Path C:\src\MyUnoApp           # text report
pwsh -File xaml-semantic-lint.ps1 -Path C:\src\MyUnoApp -Json     # JSON report
pwsh -File xaml-semantic-lint.ps1 -Path C:\src\MyUnoApp -IncludeDev
```

Exit codes: `0` clean, `1` at least one gating finding, `2` bad input. Folders named `Dev`, `Harness`, `Probe(s)` or `Test(s)` are skipped unless `-IncludeDev`.

### As an agent hook

`-Hook` reads an edit payload as JSON on stdin (`tool_input.file_path` plus `content`, `new_string`, or `edits[].new_string`) and reports only findings inside the text the edit added. It always exits `0`, so it never blocks an edit; the findings go back to the agent as context with the fix for each rule. Wire it as a post-edit hook for `*.xaml` and `*.cs` in any coding agent that supports that payload shape.

## Rules

Gating (fail the run):

| Rule | Catches | Use instead |
|---|---|---|
| CARD | `Border` with a corner radius and a fill, stroke or padding | `utu:CardContentControl` with lightweight styling keys |
| HEX | Hex colour outside a `ColorPaletteOverride` file | A theme role brush |
| CSCOLOR | Colour literal in C# (`Colors.Red`, `Color.FromArgb(...)`) | Theme resources, redrawn on theme change |
| SPACING | Margin, padding or spacing literal | Uno.Themes `Space*` tokens |
| RADIUS | Corner radius literal | Uno.Themes `Radius*` tokens |
| TOKENTHEME | App brush with one value for both themes | A role brush, or `ThemeDictionaries` |
| BACKBAR | `Navigation.Request="-"` on a page with no `NavigationBar` | `utu:NavigationBar` with a `MainCommand` |
| CODEBEHIND | Event handlers and `.Visibility =` in code-behind | Commands, `VisualStateManagerExtensions`, regions |
| OVERLAY | Overlay, sheet or drawer toggled in code-behind | A `!Route` flyout |
| RESPONSIVE | Width checks in code-behind, and every WinUI `AdaptiveTrigger` | `{utu:Responsive}`, or `utu:ResponsiveView` for a whole template |
| BUILTIN | Custom control named like a platform or Toolkit control | `RatingControl`, `ProgressBar`, `utu:Chip`... |
| ICON | Inline path geometry or shapes drawn as an icon | `SymbolIcon`/`FontIcon`, or keyed data in `Icons.xaml` |
| PLATFORMLEAK | Platform branch (`#if __ANDROID__`, `OperatingSystem.Is*()`) in a model | A platform service behind an interface |
| SYNCWAIT | `.Wait()`, `.Result`, `.GetAwaiter().GetResult()` | `await` |
| BINDVALUE | `{Binding State.Value}` in an MVUX project | `{Binding State, Mode=TwoWay}` |

Info (reported, never gating): XBINDMODE (`x:Bind` with no `Mode`), TOKEN, FONTSIZE, UTURESP, TEMPLATE, WORKAROUND.

CARD skips shapes that are not cards: zero radius, a radius on only some corners, circles, pills, and chips. BINDVALUE runs only when the nearest `.csproj` references MVUX.

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
pwsh -File lint-tests/Test-SemanticLint.ps1   # run every case and the hook payload shapes
```

Each folder under `lint-tests/fixtures/` holds source files and an `expected.json` with the exact count per rule (unlisted rules expect 0, `suppressed` checks the Supp counts). `Compare-Corpus.ps1` runs two versions of the lint on real apps and lists every finding that appeared or disappeared, which is how a rule change is checked for false positives before it moves on.

## How a rule gets in

1. Write the rule in `xaml-semantic-lint.ps1`.
2. Add fixtures: a hit, a near miss that must stay clean, and a suppressed hit.
3. Run `Compare-Corpus.ps1` on real apps and explain every added or removed finding.
4. Only then propose it for uno-lint.

Fix texts point at a local rule set (`uno-scaffolding.md`, skill names); they read as references, not links.
