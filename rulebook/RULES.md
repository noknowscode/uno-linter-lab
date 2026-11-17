# Rules

Generated from `rules.json` by `New-RuleDocs.ps1`. Edit the JSON, not this file.

| Rule | uno-lint | Profile | Needs | Status |
|---|---|---|---|---|
| [BINDVALUE](#bindvalue) | UNOL201 | recommended | MVUX | in-uno-lint |
| [BUILTIN](#builtin) | UNOL004 | recommended | any Uno Platform app | in-uno-lint |
| [CSCOLOR](#cscolor) | UNOL001 | recommended | any Uno Platform app | in-uno-lint |
| [HEX](#hex) | UNOL001 | recommended | any Uno Platform app | in-uno-lint |
| [ICON](#icon) | UNOL003 | recommended | any Uno Platform app | in-uno-lint |
| [PLATFORMLEAK](#platformleak) | - | recommended | any Uno Platform app | lab |
| [RESPONSIVE](#responsive) | UNOL005 | recommended | any Uno Platform app | in-uno-lint |
| [SYNCWAIT](#syncwait) | - | recommended | any Uno Platform app | lab |
| [TOKENTHEME](#tokentheme) | UNOL002 | recommended | any Uno Platform app | in-uno-lint |
| [XBINDMODE](#xbindmode) | - | recommended, info | any Uno Platform app | lab |
| [BACKBAR](#backbar) | UNOL102 | strict | Uno Toolkit | in-uno-lint |
| [CARD](#card) | UNOL101 | strict | Uno Toolkit | in-uno-lint |
| [CODEBEHIND](#codebehind) | UNOL103 | strict | any Uno Platform app | in-uno-lint |
| [OVERLAY](#overlay) | UNOL104 | strict | any Uno Platform app | in-uno-lint |
| [RADIUS](#radius) | - | strict | An Uno.Themes theme | lab |
| [SPACING](#spacing) | - | strict | An Uno.Themes theme | lab |

## BINDVALUE

The MVUX bindable proxy already exposes the state's value; a two-way binding to .Value on an input does not write back.

- **Profile:** recommended
- **Needs:** MVUX
- **uno-lint:** UNOL201

Bad:

```xaml
<TextBox Text="{Binding City.Value, Mode=TwoWay}" />
```

Good:

```xaml
<TextBox Text="{Binding City, Mode=TwoWay}" />
```

Fix:

- Default: bind the state itself on a two-way input: {Binding State, Mode=TwoWay}. The MVUX proxy already exposes the value. Inside a FeedView template bind {Binding Data.X}.

- **Build layer:** none yet
- **Runtime layer:** Type into the field with the App MCP and read the model state back. Not yet run: the narrowed claim is unverified.
- **Evidence:** Uno Platform's own MVUX samples (MvuxHowTos, ToDo, Commerce, uno.chefs) bind .Value for Navigation.Data, CommandParameter, DataContext, converters, ItemsSource and IsEnabled; narrowed to TwoWay input bindings.
- **Differs from uno-lint:** uno-lint flags every .Value binding: 9 hits in uno.chefs, 12 in Uno.Samples, all in working official code.
- **Fixtures:** `bindvalue`, `bindvalue-mvvm`, `corpus-bindvalue`

## BUILTIN

A re-implemented control misses the theme, accessibility and fixes the shipped one gets.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL004

Bad:

```cs
public sealed class StarRating : Control { }
```

Good:

```cs
public sealed class OrderSummary : Control { }
```

Fix:

- Default: use the platform/Toolkit control named above with lightweight styling before writing a custom control; then Windows Community Toolkit 8.x.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Uno.Samples: BusyIndicator -> ProgressRing is a true positive.
- **Differs from uno-lint:** None found.
- **Fixtures:** `builtin`

## CSCOLOR

Colours chosen in code skip the theme entirely and never change with light/dark.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL001

Bad:

```cs
public class Legend
{
    Color Overdue => Colors.Red;
}
```

Good:

```cs
public class Legend
{
    Brush Overdue => (Brush)Application.Current.Resources["ErrorBrush"];
}
```

Fix:

- Default: read the colour from theme resources (a Brush dependency property bound with {ThemeResource ...Brush}, or a lookup keyed on ActualTheme) and redraw on ActualThemeChanged.

- **Build layer:** none yet
- **Runtime layer:** Switch light/dark and check drawn colours change.
- **Evidence:** Corpus 2026-11-17: C# Markup ColorPaletteOverride.cs, Theme.Colors keys and dependency property defaults were false positives, now exempt.
- **Differs from uno-lint:** uno-lint reports these under HEX (UNOL001), so an 'allow cscolor' comment does not suppress them there. uno-lint flags dependency property defaults and MAUI C#.
- **Fixtures:** `cscolor`, `corpus-cscolor`

## HEX

A literal colour does not follow light/dark or a brand change; the theme's palette is the one place colours belong.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL001

Bad:

```xaml
<TextBlock Text="Overdue" Foreground="#D32F2F" />
```

Good:

```xaml
<TextBlock Text="Overdue" Foreground="{ThemeResource ErrorBrush}" />
```

Fix:

- Default: a theme brush ({ThemeResource ...Brush}) from the app's theme, or a colour defined once in the theme's colour override file. A literal colour does not follow light/dark or brand changes.
- With material: a Material role brush (PrimaryBrush, OnSurfaceBrush, SurfaceContainerHighBrush, OutlineVariantBrush, ErrorBrush...). The only colours an app defines live in its ColorPaletteOverride file; brand colour goes there. Status and chart colours map to Primary/Secondary/Tertiary/Error and their containers.

- **Build layer:** none yet
- **Runtime layer:** Switch light/dark with the App MCP and check the element's colour changes.
- **Evidence:** Corpus 2026-11-17: theme seed colours, fully transparent #00 colours and ThemeDictionaries colours (recommended) were false positives, now exempt.
- **Differs from uno-lint:** uno-lint also flags named colours (Fill="Red"), which the lab misses (244 hits in uno.toolkit.ui samples). uno-lint flags transparent colours and MAUI XAML.
- **Fixtures:** `hex`, `corpus-resources`, `corpus-lightweight`, `hex-themedict-strict`, `profile-recommended`

## ICON

Hand-drawn icons drift in size and stroke and cannot be swapped as a set.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL003

Bad:

```xaml
<PathIcon Data="M12,2 L22,22 L2,22 Z" />
```

Good:

```xaml
<SymbolIcon Symbol="Favorite" />
```

Fix:

- Default: SymbolIcon/FontIcon on the Fluent symbol font, or keyed path data from one open icon set (Material Symbols, Fluent System Icons) in Icons.xaml via PathIcon Data="{StaticResource ...}". Never hand-draw icons. Illustrations get "xaml-lint: allow icon - illustration".

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** uno.gallery's 88 hits are showcase pages that draw paths on purpose.
- **Differs from uno-lint:** uno-lint suppression covers one element; the lab covers the element under the comment and its children.
- **Fixtures:** `icon`, `suppression`

## PLATFORMLEAK

Platform branches in models make them untestable on other targets and scatter platform logic.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** not in uno-lint

Bad:

```cs
public partial class CameraViewModel
{
    bool CanScan => OperatingSystem.IsAndroid();
}
```

Good:

```cs
public partial class CameraViewModel(IScannerService scanner)
{
    bool CanScan => scanner.IsAvailable;
}
```

Fix:

- Default: move the branch into a platform service (interface in shared code, implementation per head or in a Platforms/ partial) and inject it; models stay platform-neutral.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** uno.ch9 view models: 2 true positives (#if !__WASM__).
- **Differs from uno-lint:** Not in uno-lint.
- **Fixtures:** `platformleak`, `corpus-platformleak`

## RESPONSIVE

Two breakpoint systems in one app drift apart; width logic in code-behind cannot be previewed or tested.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **Note:** AdaptiveTrigger hits run only with Uno Toolkit and cannot be suppressed; code-behind width checks run in every project.
- **uno-lint:** UNOL005

Bad:

```xaml
<VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState>
  <VisualState.StateTriggers><AdaptiveTrigger MinWindowWidth="720" /></VisualState.StateTriggers>
</VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
```

Good:

```xaml
<StackPanel Orientation="{utu:Responsive Narrow=Vertical, Wide=Horizontal}" />
```

Fix:

- Default: move the breakpoint into XAML: a VisualStateManager state with an AdaptiveTrigger (or add Uno Toolkit and use {utu:Responsive}). Never compare widths in code-behind or keep width flags on a view model.
- With toolkit: breakpoints are always {utu:Responsive} in XAML for a value, utu:ResponsiveView when the whole template changes (custom thresholds via a utu:ResponsiveLayout resource). No WinUI AdaptiveTrigger (not suppressible), never code-behind, never width flags on a view model.

- **Build layer:** BannedApiAnalyzers: P:Microsoft.UI.Xaml.AdaptiveTrigger.MinWindowWidth and MinWindowHeight in BannedSymbols.txt + WarningsAsErrors RS0030. Proven 2026-11-17 on Uno.Sdk 6.7.30 desktop; banning the type false-positives via BindableMetadata.g.cs.
- **Runtime layer:** Resize to Narrow and Wide with the App MCP and compare the visual tree.
- **Evidence:** A private Toolkit app had 6 AdaptiveTriggers across 3 pages. uno.gallery has 31.
- **Differs from uno-lint:** uno-lint UNOL005 only checks code-behind and its fix text suggests AdaptiveTrigger. Policy question.
- **Fixtures:** `responsive`, `toolkit-prefix`, `plain-winui`, `profile-recommended`

## SYNCWAIT

Blocking on a task freezes the UI thread and can deadlock.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** not in uno-lint

Bad:

```cs
public class OrderLoader
{
    string Load(HttpClient http) => http.GetStringAsync("/orders").Result;
}
```

Good:

```cs
public class OrderLoader
{
    async Task<string> Load(HttpClient http) => await http.GetStringAsync("/orders");
}
```

Fix:

- Default: await the task. If the caller cannot be async (constructor, property), start the load from a command or MVUX feed instead of blocking.

- **Build layer:** Microsoft.VisualStudio.Threading.Analyzers VSTHRD002 covers synchronous waits; not yet tested on an Uno Platform project.
- **Runtime layer:** none yet
- **Evidence:** Corpus 2026-11-17: .Result after a completion check (uno.ch9) and mock endpoints (uno.chefs) were false positives, now exempt.
- **Differs from uno-lint:** Not in uno-lint.
- **Fixtures:** `syncwait`, `corpus-syncwait`

## TOKENTHEME

A brush defined once outside ThemeDictionaries keeps its light-mode value in dark mode.

- **Profile:** recommended
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL002

Bad:

```xaml
<Page.Resources>
  <SolidColorBrush x:Key="AccentBrush" Color="{StaticResource BrandColor}" />
</Page.Resources>
```

Good:

```xaml
<Page.Resources>
  <ResourceDictionary>
    <ResourceDictionary.ThemeDictionaries>
      <ResourceDictionary x:Key="Light"><SolidColorBrush x:Key="AccentBrush" Color="{StaticResource BrandColor}" /></ResourceDictionary>
      <ResourceDictionary x:Key="Dark"><SolidColorBrush x:Key="AccentBrush" Color="{StaticResource BrandColorDark}" /></ResourceDictionary>
    </ResourceDictionary.ThemeDictionaries>
  </ResourceDictionary>
</Page.Resources>
```

Fix:

- Default: use a theme role brush; else define the key per theme in ThemeDictionaries; name it *Invariant/*OnDark/*OnLight/*Fixed only when its ground is fixed in both themes.

- **Build layer:** none yet
- **Runtime layer:** Switch light/dark and check the brush changes.
- **Evidence:** Corpus 2026-11-17: lightweight styling in one control's Resources, StaticResource aliases and converters keyed *Brush were false positives, now exempt.
- **Differs from uno-lint:** uno-lint does not flag a brush whose Color is a {ThemeResource}; the lab does. Unverified which is right at runtime. uno-lint flags converters keyed *Brush.
- **Fixtures:** `tokentheme`, `corpus-lightweight`, `corpus-resources`

## XBINDMODE

x:Bind defaults to OneTime, so a value that changes later never shows.

- **Profile:** recommended (info, never gating)
- **Needs:** any Uno Platform app
- **uno-lint:** not in uno-lint

Bad:

```xaml
<TextBlock Text="{x:Bind ViewModel.Title}" />
```

Good:

```xaml
<TextBlock Text="{x:Bind ViewModel.Title, Mode=OneWay}" />
```

Fix:

- Default: x:Bind is OneTime by default: add Mode=OneWay for values that change, or a comment saying OneTime is intended.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Info only: getter-only computed properties are OneTime by design.
- **Differs from uno-lint:** Not in uno-lint.
- **Fixtures:** `xbindmode`

## BACKBAR

A hand-built back button misses the platform back gesture and the shared app bar layout.

- **Profile:** strict
- **Needs:** Uno Toolkit
- **uno-lint:** UNOL102

Bad:

```xaml
<Button uen:Navigation.Request="-" Content="Back" />
```

Good:

```xaml
<utu:NavigationBar Content="Details">
  <utu:NavigationBar.MainCommand><AppBarButton uen:Navigation.Request="-" /></utu:NavigationBar.MainCommand>
</utu:NavigationBar>
```

Fix:

- Default: utu:NavigationBar with a MainCommand AppBarButton; back navigation and the Android back gesture come with it.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Corpus 2026-11-17: Navigation.Request="-" closing a ContentDialog in uno.chefs was a false positive, now exempt.
- **Differs from uno-lint:** uno-lint flags the ContentDialog close button.
- **Fixtures:** `backbar`, `corpus-dialog`

## CARD

A hand-drawn card ignores the theme's card styles and states, so every card in the app drifts a little differently.

- **Profile:** strict
- **Needs:** Uno Toolkit
- **uno-lint:** UNOL101

Bad:

```xaml
<Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}">
  <StackPanel><TextBlock Text="Order 1042" /><TextBlock Text="3 items" /></StackPanel>
</Border>
```

Good:

```xaml
<utu:CardContentControl Style="{StaticResource FilledCardContentControlStyle}">
  <StackPanel><TextBlock Text="Order 1042" /><TextBlock Text="3 items" /></StackPanel>
</utu:CardContentControl>
```

Fix:

- Default: utu:CardContentControl (Filled/Outlined/ElevatedCardContentControlStyle) + lightweight keys (CardCornerRadius, CardPadding, <Variant>CardContentBackground/BorderBrush).

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Corpus 2026-11-17: image clips and one-child badges in uno.chefs were false positives, now exempt.
- **Differs from uno-lint:** uno-lint still flags image clips and badges (lab fixture corpus-card).
- **Fixtures:** `card`, `card-shapes`, `corpus-card`

## CODEBEHIND

Logic in code-behind cannot be tested and spreads: one workaround gets copied to every page.

- **Profile:** strict
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL103

Bad:

```cs
public sealed partial class OrdersPage : Page
{
    private void OnSaveClick(object sender, RoutedEventArgs e) { }
}
```

Good:

```cs
public sealed partial class OrdersPage : Page
{
    public OrdersPage() => this.InitializeComponent();
}
```

Fix:

- Default: commands on the model (ICommand), VisualStateManager states driven by model state, or Visibility bound to the model.
- With toolkit: utu:CommandExtensions.Command, commands on the model, utu:VisualStateManagerExtensions.States bound to model state, or Visibility bound to the model.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** dotnet new unoapp (blank) wires Frame.NavigationFailed in App.xaml.cs: app-level wiring, exempt. uno.chefs keeps 2 handlers (flyout opening, map tap) as deliberate glue; strict-only.
- **Differs from uno-lint:** uno-lint lints MAUI code-behind too.
- **Fixtures:** `codebehind`, `template-app`

## OVERLAY

Hand-toggled overlays miss focus handling, dismissal and back navigation.

- **Profile:** strict
- **Needs:** any Uno Platform app
- **uno-lint:** UNOL104

Bad:

```cs
public sealed partial class SearchPage : Page
{
    void ShowFilters() => FilterSheet.Visibility = Visibility.Visible;
}
```

Good:

```cs
public sealed partial class SearchPage : Page
{
    public SearchPage() => this.InitializeComponent();
}
```

Fix:

- Default: a Flyout or ContentDialog, or Visibility bound to model state; filter state lives in the model.
- With navigation: uen:Navigation.Request="!Route" to a Page (opens as a flyout) with a DrawerFlyoutPresenter style; filter state lives in the model.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Rare in the corpus (1 hit in uno.themes).
- **Differs from uno-lint:** None found.
- **Fixtures:** `codebehind`

## RADIUS

Literal radii cannot be rescaled from the theme and drift between controls.

- **Profile:** strict
- **Needs:** An Uno.Themes theme
- **uno-lint:** not in uno-lint

Bad:

```xaml
<Button Content="Save" CornerRadius="8" />
```

Good:

```xaml
<Button Content="Save" CornerRadius="{StaticResource Radius200CornerRadius}" />
```

Fix:

- Default: Uno.Themes Radius* tokens: {StaticResource Radius200CornerRadius}. Rescale with DefaultCornerRadius on the theme.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Opinionated: uno.chefs has 52 literal radii, so this stays strict-only.
- **Differs from uno-lint:** Not in uno-lint.
- **Fixtures:** `radius`, `card-shapes`

## SPACING

Literal spacing cannot be rescaled from the theme and drifts between screens.

- **Profile:** strict
- **Needs:** An Uno.Themes theme
- **uno-lint:** not in uno-lint

Bad:

```xaml
<StackPanel Margin="16" Spacing="8" />
```

Good:

```xaml
<StackPanel Margin="{StaticResource Space400Thickness}" Spacing="{StaticResource Space200}" />
```

Fix:

- Default: Uno.Themes Space* tokens: {StaticResource Space400Thickness} for Margin/Padding, {StaticResource Space200} for Spacing. Rescale the whole app with DefaultSpacing on the theme.

- **Build layer:** none yet
- **Runtime layer:** none yet
- **Evidence:** Opinionated: uno.chefs (reference app) has 193 literal spacings, so this stays strict-only.
- **Differs from uno-lint:** Not in uno-lint.
- **Fixtures:** `spacing`, `dirbuildprops`
