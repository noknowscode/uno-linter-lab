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

| Rule | Profile | Catches | Use instead |
|---|---|---|---|
| HEX | both | Hex colour in XAML outside the palette override (recommended also allows `ThemeDictionaries`, theme seed colours and fully transparent `#00......`) | A theme brush |
| CSCOLOR | both | Colour literal in C# (`Colors.Red`, `Color.FromArgb(...)`, `SKColors.X`) outside a `ColorPaletteOverride.cs` and dependency property defaults | Theme resources, redrawn on theme change |
| TOKENTHEME | both | App `*Brush` resource with one value for both themes (not lightweight styling inside one control's `Resources`, not `StaticResource` aliases) | A theme brush, or `ThemeDictionaries` |
| RESPONSIVE | both | Width checks in code-behind; with Toolkit, every WinUI `AdaptiveTrigger` | `{utu:Responsive}` / `utu:ResponsiveView`, or a `VisualStateManager` state without Toolkit |
| BUILTIN | both | Custom control named like a platform or Toolkit control | `RatingControl`, `ProgressBar`, `utu:Chip`... |
| ICON | both | Inline path geometry or shapes drawn as an icon outside `Icons*.xaml` | `SymbolIcon`/`FontIcon`, or keyed data in `Icons.xaml` |
| PLATFORMLEAK | both | Platform branch (`#if __ANDROID__`, `OperatingSystem.Is*()`) in a model | A platform service behind an interface |
| SYNCWAIT | both | `.Wait()`, `.Result`, `.GetAwaiter().GetResult()` (not after a completion check, not in tests or mocks) | `await` |
| BINDVALUE | both | `{Binding State.Value, Mode=TwoWay}` on an input property in an MVUX project | `{Binding State, Mode=TwoWay}` |
| CARD | strict | `Border` with a corner radius and a fill, stroke or padding (not circles, pills, badges, image clips or one-corner radii) | `utu:CardContentControl` |
| BACKBAR | strict | `Navigation.Request="-"` on a page with no `NavigationBar` (not in a `ContentDialog`) | `utu:NavigationBar` with a `MainCommand` |
| CODEBEHIND | strict | Event handlers and `.Visibility =` in code-behind | Commands, visual states, bindings |
| OVERLAY | strict | Overlay, sheet or drawer toggled in code-behind | A flyout, a dialog, or a `!Route` flyout with Navigation |
| SPACING | strict | Margin, padding or spacing literal | Uno.Themes `Space*` tokens |
| RADIUS | strict | Corner radius literal | Uno.Themes `Radius*` tokens |

Info (reported, never gating): XBINDMODE (`x:Bind` with no `Mode`), TOKEN, FONTSIZE, UTURESP, TEMPLATE, WORKAROUND.

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

Each folder under `lint-tests/fixtures/` holds source files and an `expected.json` with the exact count per rule. Unlisted rules expect 0; `suppressed` checks the Supp counts, `lines` checks reported line numbers, and `"profile": "recommended"` runs a case without `-Strict`. The `corpus-*` cases reproduce false positives found in Uno Platform's own apps and samples. CI runs the suite on Windows, macOS and Linux.

`Compare-Corpus.ps1` runs two versions of the lint on real apps and lists every finding that appeared or disappeared, which is how a rule change is checked for false positives before it moves on.

## How a rule gets in

1. Write the rule in `xaml-semantic-lint.ps1`.
2. Add fixtures: a hit, a near miss that must stay clean, and a suppressed hit.
3. Run `Compare-Corpus.ps1` on real apps and explain every added or removed finding.
4. Only then propose it for uno-lint.
