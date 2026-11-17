<#
.SYNOPSIS
  Semantic-first lint for Uno Platform projects: XAML and page code-behind.

.DESCRIPTION
  Gating rules (any hit = exit 1):
    CARD        <Border> with CornerRadius plus Background, BorderBrush or Padding.
                -> utu:CardContentControl + lightweight keys.
    HEX         Hex colour literal in XAML anywhere except the palette override
                (ColorPaletteOverride*.xaml / ColorOverride*.xaml). App token and palette
                files are NOT exempt: they outrank the theme, so Studio's theme editor
                cannot reach them.
                -> Material role brush (PrimaryBrush, OnSurfaceBrush, SurfaceContainerHighBrush,
                   OutlineVariantBrush, ErrorBrush...); brand colours go into the palette override.
    CSCOLOR     Colour literal in C# (Color.FromArgb, ColorHelper.FromArgb, new SKColor,
                SKColor.Parse, SKColors.X, Colors.X, a "#rrggbb" string). Transparent is allowed.
                -> read the role colour from theme resources and redraw on theme change.
    SPACING     Numeric Margin/Padding/Spacing/RowSpacing/ColumnSpacing literal, a <Thickness>
                resource with a numeric value, or new Thickness(n) in C#. 0 is allowed.
                -> Uno.Themes Space* tokens ({StaticResource Space400Thickness}, Space400).
    RADIUS      Numeric CornerRadius literal, a <CornerRadius> resource with a numeric
                value, or new CornerRadius(n) in C#. 0 is allowed.
                -> Uno.Themes Radius* tokens ({StaticResource Radius200CornerRadius}).
                Page layout limits (MaxWidth, Width) are not checked: they stay local.
    TOKENTHEME  App-defined *Brush key outside ThemeDictionaries with no invariant
                marker, in any XAML except ColorPaletteOverride*. It will not follow
                light/dark. -> theme role, or define it per theme, or name it
                *Invariant/*OnDark/*OnLight/*Fixed when its ground is fixed.
    BACKBAR     Navigation.Request="-" in a XAML file with no NavigationBar.
                -> utu:NavigationBar with a MainCommand AppBarButton.
    CODEBEHIND  Event handler (object sender, ...) or .Visibility assignment in
                page/control code-behind (*.xaml.cs).
                -> utu:CommandExtensions, model commands, VisualStateManagerExtensions,
                   nested Visibility regions.
    OVERLAY     Code-behind toggling Visibility of an element named *Overlay, *Sheet,
                *Scrim, *Drawer, *Popup or *Panel.
                -> uen:Navigation.Request="!Route" to a Page (opens as a flyout),
                   DrawerFlyoutPresenter styles for sheets and side drawers.
    RESPONSIVE  Size comparison in code-behind (NewSize.Width >= x, ActualWidth < x), or any
                WinUI AdaptiveTrigger (XAML anywhere, ControlTemplates included, or new AdaptiveTrigger
                in C#). AdaptiveTrigger hits cannot be suppressed: the app has no AdaptiveTriggers at all.
                -> {utu:Responsive} for every width-dependent value, utu:ResponsiveView when the
                   whole template changes; never AdaptiveTrigger, code-behind or view-model width flags.
    BUILTIN     Custom control whose name matches a platform/Toolkit control
                (StarRating -> RatingControl, MacroBar -> ProgressBar, *Card -> CardContentControl).
    ICON        Icon geometry outside an Icons*.xaml file: inline Path/PathIcon Data
                mini-language, an inline PathGeometry/GeometryGroup, or basic shapes
                (Ellipse, Rectangle, Line, Polyline, Polygon) composed inside a Viewbox.
                -> SymbolIcon/FontIcon, or keyed path data from one open icon set in
                   Icons.xaml used via PathIcon Data="{StaticResource ...}".
                ControlTemplates are skipped (template parts, counted as TEMPLATE info).
    PLATFORMLEAK  Platform branch (#if __ANDROID__/__IOS__/__WASM__/HAS_UNO*/WINDOWS,
                OperatingSystem.Is*(), RuntimeInformation.IsOSPlatform) in a *Model.cs or
                *ViewModel.cs. -> a platform service behind an interface, or a Platforms/
                partial; the model stays platform-neutral.
    BINDVALUE   {Binding State.Value} outside a DataTemplate in a project that references MVUX
                (UnoFeatures Mvux or Uno.Extensions.Reactive). Shows empty, writes nothing.
                -> {Binding State, Mode=TwoWay}; {Binding Data.X} inside a FeedView template.
    SYNCWAIT    Blocking wait on a task in app code: .Wait(), .GetAwaiter().GetResult(),
                SomethingAsync(...).Result, task.Result. -> await it; blocking the UI
                thread freezes the app and can deadlock. Test projects are skipped.
  Info (reported, never gating):
    XBINDMODE   {x:Bind a.b} with no Mode outside a DataTemplate. x:Bind defaults to
                OneTime, so a value that changes later never shows. Event and Command
                attributes, DataContext and CommandParameter are skipped. Getter-only
                computed properties are OneTime by design, so this stays info. -> Mode=OneWay, or a comment that OneTime is meant.
    TOKEN       References to app-defined *Brush keys (each skipped the Material roles).
    FONTSIZE    Literal FontSize attributes (use a Material text style instead).
    TEMPLATE    App-authored ControlTemplates (Borders inside them are not CARD hits).

  Dev/harness files (a Dev, Harness, Probe or Tests path segment, or *Harness*/*Probe* in
  the name) are skipped unless -IncludeDev.

  CARD skips shapes that are not cards: zero radius, radius on only some corners, circles,
  pills and chips (literal radius 12+ around one TextBlock or icon).

  Suppress one deliberate hit with a comment on its line or in the comment lines directly above
  it (up to 3; any other line stops the search). In XAML put it above the element's start tag.
  The uno-lint: prefix and "allow all" work too. Suppressed hits are counted in the Supp column.
  Reason required:
    <!-- xaml-lint: allow card - image clip with a placeholder fill -->
    // xaml-lint: allow codebehind - video transport glue, no Toolkit equivalent
  Rule names in suppressions are lowercase: card, hex, cscolor, spacing, radius, tokentheme,
  backbar, codebehind, overlay, responsive, builtin, icon, platformleak, syncwait, bindvalue,
  xbindmode, all. AdaptiveTrigger hits (RESPONSIVE) cannot be suppressed.

.EXAMPLE
  xaml-semantic-lint.ps1 -Path C:\src\MyUnoApp
  xaml-semantic-lint.ps1 -Path . -Json
  <hook JSON on stdin> | xaml-semantic-lint.ps1 -Hook

.NOTES
  Exit code (Path mode): 0 = clean, 1 = gating findings, 2 = bad input.
  Hook mode always exits 0 and reports only findings inside the text the edit added.
#>
#Requires -Version 7.0
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(ParameterSetName = 'Path', Position = 0)]
    [string] $Path = '.',
    [Parameter(ParameterSetName = 'Path')]
    [switch] $Json,
    [Parameter(ParameterSetName = 'Path')]
    [int] $Top = 12,
    [Parameter(ParameterSetName = 'Path')]
    [switch] $IncludeDev,
    [Parameter(ParameterSetName = 'Hook')]
    [switch] $Hook,
    # Strict profile: adds the opinionated rules (CARD, BACKBAR, CODEBEHIND, OVERLAY, SPACING, RADIUS)
    # and limits colours to the palette override. The default profile runs rules that hold for any
    # Uno Platform app.
    [switch] $Strict
)

$ErrorActionPreference = 'Stop'

# The rulebook is the single source for each rule's profile, gating, title and fix text; this
# script owns detection only. rulebook/rules.json also feeds the docs and the agent rules.
$Rulebook = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'rulebook/rules.json') -Raw | ConvertFrom-Json
$RuleById = @{}; foreach ($r in $Rulebook.rules) { $RuleById[$r.id] = $r }
$Gating     = @($Rulebook.rules | Where-Object gating | ForEach-Object id)
$InfoRules  = @($Rulebook.rules | Where-Object { -not $_.gating } | ForEach-Object id)
$StrictOnly = @($Rulebook.rules | Where-Object profile -eq 'strict' | ForEach-Object id)

# Fix text for this project: the first feature-specific variant the project has, else the default.
function Get-Fix([string] $rule, $ctx) {
    $f = $RuleById[$rule].fix
    foreach ($k in 'material', 'toolkit', 'navigation', 'mvux') {
        if ($f.PSObject.Properties[$k] -and $ctx -and $ctx.$k) { return $f.$k }
    }
    $f.default
}

$PaletteName = '(?i)(palette|colou?rs?|tokens?)[^\\/]*\.xaml$'
$IconName    = '(?i)icons?[^\\/]*\.xaml$'
$InlineDataRx = [regex]::new('<(Path|PathIcon)\b[^>]*?\bData\s*=\s*"\s*(?:F[01]\s*)?[Mm]', 'Singleline')
$GeometryRx   = [regex]::new('<(PathGeometry|GeometryGroup)\b')
$ViewboxRx    = [regex]::new('<Viewbox\b.*?</Viewbox>', 'Singleline')
$ShapeRx      = [regex]::new('<(Ellipse|Rectangle|Line|Polyline|Polygon)\b')
# Theme palette override files (Material ColorPaletteOverride, Simple ColorOverrideDictionary files).
$MaterialPal = '(?i)Colou?r(Palette)?Override[^\\/]*\.xaml$'
$DevPath     = '(?i)[\\/](Dev|Harness|Probes?|Tests?)[\\/]|Harness|Probe'
$BorderRx    = [regex]::new('<Border\b[^>]*>', 'Singleline')
$HexRx       = [regex]::new('(?:=\s*"|>)\s*(#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3,4}))\s*(?:"|<)')
# Numeric literal list: "16", "0,8,0,0", "12 4". All-zero values are allowed.
$SpaceAttrRx = [regex]::new('\b(Margin|Padding|Spacing|RowSpacing|ColumnSpacing)\s*=\s*"\s*(-?[\d.]+(?:\s*[, ]\s*-?[\d.]+)*)\s*"')
$RadiusAttrRx = [regex]::new('\bCornerRadius\s*=\s*"\s*([\d.]+(?:\s*[, ]\s*[\d.]+)*)\s*"')
$ThickResRx  = [regex]::new('<Thickness\b[^>]*>\s*(-?[\d.]+(?:\s*[, ]\s*-?[\d.]+)*)\s*</Thickness>')
$RadiusResRx = [regex]::new('<CornerRadius\b[^>]*>\s*([\d.]+(?:\s*[, ]\s*[\d.]+)*)\s*</CornerRadius>')
$SetterRx    = [regex]::new('<Setter\s+Property\s*=\s*"(Margin|Padding|Spacing|RowSpacing|ColumnSpacing|CornerRadius)"\s+Value\s*=\s*"\s*(-?[\d.]+(?:\s*[, ]\s*-?[\d.]+)*)\s*"')
$FontSizeRx  =[regex]::new('\bFontSize\s*=\s*"\s*[\d.]+\s*"')
# Constructors only count with a numeric first argument: new SKColor(c.R, c.G, c.B, c.A) converts a theme colour.
$CsColorRx   = [regex]::new('\b(?:Color|ColorHelper)\.From(?:Argb|Rgb)\s*\(\s*(?:0x|\d)|\bnew\s+SKColor\s*\(\s*(?:0x|\d)|\bSKColor\.Parse\s*\(|\bSKColors\.(?!Transparent\b|Empty\b)\w+|(?<!\bTheme\.)\bColors\.(?!Transparent\b)\w+|"#(?:[0-9A-Fa-f]{8}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{3})"')
$CsThickRx   = [regex]::new('\bnew\s+(Thickness|CornerRadius)\s*\(\s*(-?[\d.]+(?:\s*,\s*-?[\d.]+)*)\s*\)')
# Brush resources only: a *Brush element (SolidColorBrush, LinearGradientBrush...) keyed *Brush.
# Converters keyed *Brush and <StaticResource> aliases of an existing brush are not new colours.
$BrushKeyRx  = [regex]::new('<(?:\w+:)?\w*Brush\b[^>]*?\bx:Key\s*=\s*"([A-Za-z0-9_.]+Brush)"', 'Singleline')
$TemplateRx  = [regex]::new('<ControlTemplate\b.*?</ControlTemplate>', 'Singleline')
# Any namespace prefix: apps declare Uno Toolkit as utu:, toolkit:, ut: and so on.
$ShadowRx    = [regex]::new('<(\w+):ShadowContainer\b.*?</\1:ShadowContainer>', 'Singleline')
$ControlResRx = [regex]::new('<((?:\w+:)?(\w+))\.Resources>.*?</\1\.Resources>', 'Singleline')
$ThemeDictRx = [regex]::new('<ResourceDictionary\.ThemeDictionaries>.*?</ResourceDictionary\.ThemeDictionaries>', 'Singleline')
$BackRx      = [regex]::new('Navigation\.Request\s*=\s*"-"')
$HandlerRx   = [regex]::new('void\s+(\w+)\s*\(\s*object\??\s+sender\s*,')
$VisRx       = [regex]::new('\b(\w+)\s*\.\s*Visibility\s*=')
# WinUI AdaptiveTrigger in any namespace prefix (<AdaptiveTrigger, <win:AdaptiveTrigger) and in C#.
$AdaptiveXamlRx = [regex]::new('<(?:\w+:)?AdaptiveTrigger\b')
$AdaptiveCsRx   = [regex]::new('\bnew\s+(?:[\w.]+\.)?AdaptiveTrigger\b')
$SizeRx      =[regex]::new('\b(NewSize\.(?:Width|Height)|ActualWidth|ActualHeight|Bounds\.(?:Width|Height))\s*(<=|>=|<|>)')
$ClassRx     = [regex]::new('class\s+(\w+)\s*:\s*(?:[\w.]+\.)?(Control|ContentControl|UserControl|Panel|Button|ToggleButton|FrameworkElement|Grid|StackPanel|Canvas|Border|ItemsControl|SKCanvasElement)\b')
$OverlayName = '(?i)(overlay|sheet|scrim|drawer|popup|panel)$'
$InvariantKey = '(?i)invariant|ondark|onlight|fixed'
$XBindRx     = [regex]::new('(\w+)\s*=\s*"\{x:Bind\s+([\w.]+\.[\w.]+)\s*(,[^}]*)?\}"')
$XBindSkip   = '(?i)^(Click|Tapped|DoubleTapped|Loaded|Unloaded|Toggled|ItemClick|\w*Changed|\w*Pressed|\w*Released|\w*Requested|\w*Invoked|\w*Command|CommandParameter|DataContext)$'
$DataTplRx   = [regex]::new('<DataTemplate\b.*?</DataTemplate>', 'Singleline')
$ModelName   = '(?i)(View)?Model\.cs$'
$PlatIfRx    = [regex]::new('(?m)^[ \t]*#(?:el)?if\b.*\b(__[A-Z]+__|HAS_UNO\w*|WINDOWS|WINAPPSDK)\b')
$PlatApiRx   = [regex]::new('\b(OperatingSystem\.Is\w+|RuntimeInformation\.IsOSPlatform)\s*\(')
$TestFile    = '(?i)\.Tests?[\\/]|Tests?\.cs$'
$SyncWaitRx  = [regex]::new('\.Wait\(\s*\)|\.GetAwaiter\(\)\s*\.GetResult\(\)|Async\([^;{}]*?\)\s*\.Result\b|\b\w*[Tt]ask\.Result\b')

# Name pattern -> (suggested control, token whose presence in the companion XAML means it is already used)
$BuiltinMap = @(
    @('(?i)rating|stars?$',                     'RatingControl',                                   'RatingControl'),
    @('(?i)progress|meter|gauge|macro\w*bar',   'ProgressBar (lightweight keys)',                  'ProgressBar'),
    @('(?i)tabbar|tabs$|segment',               'utu:TabBar (SegmentedStyle / TopTabBarStyle)',    'TabBar'),
    @('(?i)(nav|app|top|title|header)bar',      'utu:NavigationBar',                               'NavigationBar'),
    @('(?i)card',                               'utu:CardContentControl + lightweight keys',       'CardContentControl'),
    @('(?i)chip',                               'utu:Chip / utu:ChipGroup',                        'Chip'),
    @('(?i)drawer|sheet',                       'Flyout + DrawerFlyoutPresenter style via a ! route', 'Flyout'),
    @('(?i)pips|dots|pager',                    'PipsPager / utu:SelectorExtensions.PipsPager',    'Pips'),
    @('(?i)toggle|switch',                      'ToggleSwitch / ToggleButton',                     'Toggle'),
    @('(?i)spinner|loader|busy',                'ProgressRing / utu:LoadingView',                  'Progress'),
    @('(?i)bar$',                               'ProgressBar or utu:NavigationBar',                'Bar')
)

# Only a TwoWay binding on an input property: Uno Platform's own MVUX samples bind .Value for
# Navigation.Data, CommandParameter, DataContext and converters, so those are not flagged.
$BindValueRx = [regex]::new('(?<!Navigation\.)\b(Text|IsChecked|IsOn|Value|SelectedItem|SelectedIndex|SelectedValue|Date|Time|SelectedDate|SelectedTime)\s*=\s*"\{Binding\s+(?:Path\s*=\s*)?([\w.]*\w\.Value)\s*,[^}]*\bMode\s*=\s*TwoWay\b[^}]*\}"')
# Project context: which Uno Platform features the file's project references. Rules whose advice
# needs a feature only run when the project has it (as uno-lint does), so a plain WinUI/Fluent app
# is never told to use Toolkit controls or Uno.Themes tokens it does not have.
# Sources: the nearest .csproj above the file, every Directory.Build.props / Directory.Packages.props
# from there up, and the project's App.xaml; plus the file's own xmlns declarations.
$script:DirProject = @{}
$script:ProjectCtx = @{}
function Find-Project([string] $dir) {
    $seen = [System.Collections.Generic.List[string]]::new()
    $found = $null
    while ($dir) {
        if ($script:DirProject.ContainsKey($dir)) { $found = $script:DirProject[$dir]; break }
        $seen.Add($dir)
        $p = Get-ChildItem -LiteralPath $dir -Filter *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { $found = $p.FullName; break }
        $parent = Split-Path $dir -Parent
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    foreach ($d in $seen) { $script:DirProject[$d] = $found }
    $found
}

function Get-ProjectContext([string] $file, [string] $text = '') {
    $proj = if ($file) { Find-Project (Split-Path $file -Parent) } else { $null }
    $base = @{ Project = $proj; Toolkit = $false; Themes = $false; Material = $false; Navigation = $false; Mvux = $false; Maui = $false }
    if ($proj) {
        if (-not $script:ProjectCtx.ContainsKey($proj)) {
            $parts = [System.Collections.Generic.List[string]]::new()
            $parts.Add((Get-Content -LiteralPath $proj -Raw))
            $d = Split-Path $proj -Parent
            $app = Join-Path $d 'App.xaml'
            if (Test-Path -LiteralPath $app) { $parts.Add((Get-Content -LiteralPath $app -Raw)) }
            while ($d) {
                foreach ($n in 'Directory.Build.props', 'Directory.Packages.props') {
                    $f = Join-Path $d $n
                    if (Test-Path -LiteralPath $f) { $parts.Add((Get-Content -LiteralPath $f -Raw)) }
                }
                $parent = Split-Path $d -Parent
                if (-not $parent -or $parent -eq $d) { break }
                $d = $parent
            }
            $all = $parts -join "`n"
            $features = ([regex]::Matches($all, '(?is)<UnoFeatures>(.*?)</UnoFeatures>') | ForEach-Object { $_.Groups[1].Value }) -join ';'
            $script:ProjectCtx[$proj] = @{
                Toolkit    = $features -match '(?i)\bToolkit\b' -or $all -match 'Uno\.Toolkit'
                Material   = $features -match '(?i)\bMaterial\b' -or $all -match 'Uno\.Material|\bMaterial(Toolkit)?Theme\b'
                Themes     = $features -match '(?i)\b(Material|Cupertino|Simple\w*)\b' -or $all -match 'Uno\.(Themes|Material|Cupertino|Simple)|\b(Material|Cupertino|Simple)(Toolkit)?Theme\b'
                Navigation = $features -match '(?i)\bNavigation\b' -or $all -match 'Uno\.Extensions\.Navigation'
                Mvux       = $features -match '(?i)\bMvux\b' -or $all -match 'Uno\.Extensions\.Reactive'
                # A .NET MAUI project (for example MAUI controls embedded in an Uno Platform app)
                # uses MAUI XAML and APIs; none of these rules apply to it.
                Maui       = (Get-Content -LiteralPath $proj -Raw) -match '(?i)<UseMaui>\s*true\s*</UseMaui>'
            }
        }
        foreach ($k in $script:ProjectCtx[$proj].Keys) { $base[$k] = $script:ProjectCtx[$proj][$k] }
    }
    # A file's own namespace declarations prove a reference, including files outside any project.
    if ($text -match 'using:Uno\.Toolkit\.UI') { $base.Toolkit = $true }
    if ($text -match 'using:Uno\.Extensions\.Navigation') { $base.Navigation = $true }
    if ($text -match 'using:Uno\.Extensions\.Reactive') { $base.Mvux = $true }
    if ($text -match 'using:Uno\.(Material|Themes|Cupertino)') { $base.Themes = $true }
    [pscustomobject]$base
}

function Test-NonZero([string] $values) {
    @($values -split '[,\s]+' | Where-Object { $_ -and [double]$_ -ne 0 }).Count -gt 0
}

function New-Finding($rule, $text, $index, $detail) {
    [pscustomobject]@{ Rule = $rule; Index = $index; Line = ([regex]::Matches($text.Substring(0, $index), "`n")).Count + 1; Detail = $detail }
}

# Suppressed hits per rule, reported as the Supp column so allow comments stay visible.
$script:Suppressed = @{}
# Set by Get-XamlIssues / Get-CsIssues: XAML hits anchor on their element's start tag.
$script:IsXaml = $false

# A hit is suppressed by an allow comment on its own line, or in the comment lines directly above
# it (at most 3, blank lines skipped, lines of a multi-line comment included). Any other line stops
# the search, so one comment never covers the elements after the one it annotates. In XAML the
# search starts at the element's start tag, so an attribute on a multi-line element is covered by
# a comment above the element. Accepts the uno-lint: prefix and "all".
$script:XamlScopes = @{}
# XAML: an allow comment covers the element that directly follows it, children included, so one
# comment above an illustration's Canvas or a legend's StackPanel covers the group (seen in real
# apps) and never leaks onto a sibling. Spans are cached per file text and rule.
function Get-XamlAllowSpans([string] $text, [string] $rule) {
    $key = "$($text.GetHashCode())|$rule"
    if ($script:XamlScopes.ContainsKey($key)) { return $script:XamlScopes[$key] }
    $spans = [System.Collections.Generic.List[object]]::new()
    $rx = [regex]::new("<!--(?:(?!-->).)*?(?:xaml|uno)-lint:\s*allow\s+(?:$rule|all)\b\s*-\s*\S.*?-->", 'Singleline,IgnoreCase')
    foreach ($c in $rx.Matches($text)) {
        $next = [regex]::new('\G(?:\s|<!--.*?-->)*<([\w:.]+)', 'Singleline').Match($text, $c.Index + $c.Length)
        if (-not $next.Success) { continue }
        $start = $next.Index + $next.Length - $next.Groups[1].Length - 1
        $spans.Add(@($start, (Get-XamlElementEnd $text $start $next.Groups[1].Value)))
    }
    $script:XamlScopes[$key] = $spans
    $spans
}

# End index of the element whose start tag begins at $start (self-closing or matched by name).
function Get-XamlElementEnd([string] $text, [int] $start, [string] $name) {
    $tagEnd = [regex]::new('\G<[^>]*?(/?)>', 'Singleline').Match($text, $start)
    if (-not $tagEnd.Success) { return $start + 1 }
    if ($tagEnd.Groups[1].Value -eq '/') { return $tagEnd.Index + $tagEnd.Length }
    $n = [regex]::Escape($name)
    $depth = 1
    foreach ($m in [regex]::new("<(/?)$n(?=[\s/>])[^>]*?(/?)>", 'Singleline').Matches($text, $tagEnd.Index + $tagEnd.Length)) {
        if ($m.Groups[1].Value -eq '/') { $depth-- } elseif ($m.Groups[2].Value -ne '/') { $depth++ }
        if ($depth -eq 0) { return $m.Index + $m.Length }
    }
    $text.Length
}

function Test-Suppressed([string] $text, [int] $index, [string] $rule) {
    $allow = "(?:xaml|uno)-lint:\s*allow\s+(?:{0}|all)\b\s*-\s*\S" -f $rule
    if ($script:IsXaml) {
        $hitLineStart = $text.LastIndexOf("`n", [Math]::Max(0, $index - 1)) + 1
        $hitLineEnd = $text.IndexOf("`n", $index); if ($hitLineEnd -lt 0) { $hitLineEnd = $text.Length }
        $ok = ($text.Substring($hitLineStart, $hitLineEnd - $hitLineStart) -match $allow) -or
              [bool](Get-XamlAllowSpans $text $rule | Where-Object { $index -ge $_[0] -and $index -lt $_[1] })
        if ($ok) { $script:Suppressed[$rule.ToUpper()] = 1 + [int]$script:Suppressed[$rule.ToUpper()] }
        return $ok
    }
    $hitLineStart = $text.LastIndexOf("`n", [Math]::Max(0, $index - 1)) + 1
    $hitLineEnd = $text.IndexOf("`n", $index); if ($hitLineEnd -lt 0) { $hitLineEnd = $text.Length }
    $anchor = $index
    if ($script:IsXaml) { $lt = $text.LastIndexOf('<', $index); if ($lt -ge 0) { $anchor = $lt } }
    $lineStart = $text.LastIndexOf("`n", [Math]::Max(0, $anchor - 1)) + 1
    $ok = $text.Substring($lineStart, $hitLineEnd - $lineStart) -match $allow
    if (-not $ok) {
        $lines = $text.Substring(0, $lineStart) -split "`n"
        $seen = 0; $inBlock = $false
        for ($i = $lines.Count - 1; $i -ge 0 -and $seen -lt 3; $i--) {
            $l = $lines[$i].Trim()
            if (-not $l) { continue }
            $isComment = $inBlock -or $l -match '^(<!--|//|/\*|\*)' -or $l -match '(-->|\*/)$'
            if (-not $isComment) { break }
            if ($l -match '(-->|\*/)$' -and $l -notmatch '^(<!--|/\*)') { $inBlock = $true }
            if ($l -match '^(<!--|/\*)') { $inBlock = $false }
            $seen++
            if ($l -match $allow) { $ok = $true; break }
        }
    }
    if ($ok) { $script:Suppressed[$rule.ToUpper()] = 1 + [int]$script:Suppressed[$rule.ToUpper()] }
    $ok
}

# Shapes a rounded Border draws that are not cards (ported from uno-lint UNOL101): a zero radius,
# a radius on only some corners (tab or sheet edge), a circle (equal Width/Height, radius >= half),
# a pill (radius >= half the Height), a chip (radius 12+ around one TextBlock or icon).
# Only literal radii are judged; a {StaticResource} radius stays a CARD hit.
function Test-CardShapeExempt([string] $tag, [string] $text, [int] $after) {
    # One child: text or an icon makes a badge or chip; an Image makes an image clip.
    if ($tag -notmatch '/>\s*$') {
        $body = $text.Substring($after, [Math]::Min(1500, $text.Length - $after))
        if ($body -match '^\s*<(TextBlock|FontIcon|SymbolIcon|PathIcon|BitmapIcon|ImageIcon|Image)\b[^<>]*/>\s*</Border>') { return $true }
    }
    if ($tag -notmatch '\bCornerRadius\s*=\s*"\s*([\d.]+(?:\s*[, ]\s*[\d.]+)*)\s*"') { return $false }
    $r = @($Matches[1] -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [double]$_ })
    $max = ($r | Measure-Object -Maximum).Maximum
    if ($max -eq 0) { return $true }
    if ($r.Count -eq 4 -and ($r | Where-Object { $_ -eq 0 })) { return $true }
    $w = if ($tag -match '\bWidth\s*=\s*"\s*([\d.]+)\s*"') { [double]$Matches[1] } else { $null }
    $h = if ($tag -match '\bHeight\s*=\s*"\s*([\d.]+)\s*"') { [double]$Matches[1] } else { $null }
    if ($w -and $h -and $w -eq $h -and $max -ge $w / 2) { return $true }
    if ($h -and $max -ge $h / 2) { return $true }
    $false
}

function Get-XamlIssues([string] $text, [string] $name, [string] $fullPath) {
    $out = [System.Collections.Generic.List[object]]::new()
    $script:IsXaml = $true
    # Only WinUI XAML: a root element whose default namespace is another XAML dialect (for example
    # .NET MAUI controls embedded in an Uno Platform app) follows other rules.
    $root = [regex]::Match($text, '^\s*(?:<\?.*?\?>\s*|<!--.*?-->\s*)*<[\w:.]+\b[^>]*>', 'Singleline').Value
    if ($root -match '\sxmlns\s*=\s*"([^"]+)"' -and $Matches[1] -ne 'http://schemas.microsoft.com/winfx/2006/xaml/presentation') { return $out }
    $ctx = Get-ProjectContext $fullPath $text
    # Borders inside a ControlTemplate are template parts; re-templating is counted as TEMPLATE info.
    $templates = @($TemplateRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    # A Border inside a ShadowContainer with no Background only shapes the shadow (Toolkit rule:
    # Background belongs on the container), so it is not a card.
    $shadows = @($ShadowRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    # CARD suggests utu:CardContentControl, so it needs Uno Toolkit.
    $borders = if ($ctx.Toolkit) { $BorderRx.Matches($text) } else { @() }
    foreach ($m in $borders) {
        $tag = $m.Value
        if ($tag -notmatch '\bCornerRadius\s*=' -or $tag -notmatch '\b(Background|BorderBrush|Padding)\s*=') { continue }
        if ($templates | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
        if ($tag -notmatch '\bBackground\s*=' -and ($shadows | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] })) { continue }
        if (Test-CardShapeExempt $tag $text ($m.Index + $m.Length)) { continue }
        if (Test-Suppressed $text $m.Index 'card') { continue }
        $n = if ($tag -match 'x:Name\s*=\s*"([^"]+)"') { " x:Name=`"$($Matches[1])`"" } else { '' }
        $out.Add((New-Finding 'CARD' $text $m.Index "<Border$n> drawn as a card"))
    }
    # Only the palette override may hold colours (it is what Studio's theme editor writes).
    # A colour defined per theme in ThemeDictionaries follows light/dark, so only the strict profile
    # (palette override only) flags it.
    $themeDicts = @($ThemeDictRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    if ($name -notmatch $MaterialPal) {
        foreach ($m in $HexRx.Matches($text)) {
            if (-not $Strict -and ($themeDicts | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] })) { continue }
            # Theme seed colours (<utu:ThemeColors PrimarySeed="#...">) are how a theme gets its palette.
            $ls = $text.LastIndexOf('<', $m.Index)
            if ($ls -ge 0 -and $text.Substring($ls, $m.Index - $ls) -match '(?s)^<(\w+:)?ThemeColors\b|\b\w*Seed\s*=\s*"?\s*$') { continue }
            # Alpha 00 is fully transparent: a hit-test fill, not a colour.
            if ($m.Groups[1].Value -match '^#(00[0-9A-Fa-f]{6}|0[0-9A-Fa-f]{3})$') { continue }
            if (Test-Suppressed $text $m.Index 'hex') { continue }
            $out.Add((New-Finding 'HEX' $text $m.Index "literal $($m.Groups[1].Value)"))
        }
    }
    # SPACING and RADIUS suggest Uno.Themes Space*/Radius* tokens, so they need an Uno.Themes theme.
    if ($name -notmatch $MaterialPal -and $ctx.Themes) {
        foreach ($rx in $SpaceAttrRx, $ThickResRx) {
            foreach ($m in $rx.Matches($text)) {
                $vals = $m.Groups[$m.Groups.Count - 1].Value
                if (-not (Test-NonZero $vals)) { continue }
                if (Test-Suppressed $text $m.Index 'spacing') { continue }
                $what = if ($m.Groups.Count -gt 2) { "$($m.Groups[1].Value)=`"$vals`"" } else { "<Thickness>$vals" }
                $out.Add((New-Finding 'SPACING' $text $m.Index "literal $what"))
            }
        }
        foreach ($rx in $RadiusAttrRx, $RadiusResRx) {
            foreach ($m in $rx.Matches($text)) {
                $vals = $m.Groups[1].Value
                if (-not (Test-NonZero $vals)) { continue }
                if (Test-Suppressed $text $m.Index 'radius') { continue }
                $out.Add((New-Finding 'RADIUS' $text $m.Index "literal CornerRadius $vals"))
            }
        }
        foreach ($m in $SetterRx.Matches($text)) {
            if (-not (Test-NonZero $m.Groups[2].Value)) { continue }
            $rule = if ($m.Groups[1].Value -eq 'CornerRadius') { 'RADIUS' } else { 'SPACING' }
            if (Test-Suppressed $text $m.Index $rule.ToLower()) { continue }
            $out.Add((New-Finding $rule $text $m.Index "Setter $($m.Groups[1].Value)=`"$($m.Groups[2].Value)`""))
        }
    }
    if ($name -notmatch $MaterialPal) {
        $spans = @($ThemeDictRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
        # Lightweight styling: brushes in one control's Resources (<Button.Resources>) override that
        # control's own keys, which is the documented way to restyle a single control.
        $local = @($ControlResRx.Matches($text) | Where-Object { $_.Groups[2].Value -notmatch '^(Page|UserControl|Application|ResourceDictionary|Window|ContentDialog)$' } |
                   ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
        foreach ($m in $BrushKeyRx.Matches($text)) {
            $key = $m.Groups[1].Value
            if ($key -match $InvariantKey) { continue }
            if ($spans | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
            if ($local | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
            if (Test-Suppressed $text $m.Index 'tokentheme') { continue }
            $out.Add((New-Finding 'TOKENTHEME' $text $m.Index "$key has one value for both themes"))
        }
    }
    # In a ContentDialog, Navigation.Request="-" closes the dialog; it is not a back button.
    if ($ctx.Toolkit -and $text -notmatch 'NavigationBar' -and $text -notmatch '^\s*(<\?xml[^>]*>\s*)?(<!--.*?-->\s*)*<(\w+:)?ContentDialog\b') {
        foreach ($m in $BackRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'backbar') { continue }
            $out.Add((New-Finding 'BACKBAR' $text $m.Index 'hand-built back button; no NavigationBar on this page'))
        }
    }
    if ($name -notmatch $IconName) {
        $inTemplate = { param($i) $templates | Where-Object { $i -ge $_[0] -and $i -lt $_[1] } }
        foreach ($m in $InlineDataRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $out.Add((New-Finding 'ICON' $text $m.Index "inline <$($m.Groups[1].Value) Data> path geometry"))
        }
        foreach ($m in $GeometryRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $out.Add((New-Finding 'ICON' $text $m.Index "inline <$($m.Groups[1].Value)>"))
        }
        foreach ($m in $ViewboxRx.Matches($text)) {
            if (& $inTemplate $m.Index) { continue }
            $shapes = $ShapeRx.Matches($m.Value)
            if ($shapes.Count -eq 0) { continue }
            if (Test-Suppressed $text $m.Index 'icon') { continue }
            $kinds = ($shapes | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique) -join '/'
            $out.Add((New-Finding 'ICON' $text $m.Index "Viewbox composed of $($shapes.Count) shape(s) ($kinds)"))
        }
    }
    # With Uno Toolkit, responsive is {utu:Responsive} / utu:ResponsiveView only: no exemptions, no
    # suppression. Without Toolkit, AdaptiveTrigger is the WinUI way and stays allowed.
    $triggers = if ($ctx.Toolkit) { $AdaptiveXamlRx.Matches($text) } else { @() }
    foreach ($m in $triggers) {
        $out.Add((New-Finding 'RESPONSIVE' $text $m.Index 'WinUI AdaptiveTrigger'))
    }
    # Item templates usually bind immutable records, where OneTime is right.
    $dataTpls = @($DataTplRx.Matches($text) | ForEach-Object { , @($_.Index, ($_.Index + $_.Length)) })
    foreach ($m in $XBindRx.Matches($text)) {
        if ($m.Groups[1].Value -match $XBindSkip) { continue }
        if ($m.Groups[3].Value -match '\bMode\s*=') { continue }
        if ($dataTpls | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
        if (Test-Suppressed $text $m.Index 'xbindmode') { continue }
        $out.Add((New-Finding 'XBINDMODE' $text $m.Index "$($m.Groups[1].Value)=`"{x:Bind $($m.Groups[2].Value)}`" is OneTime"))
    }
    # MVUX bindable proxies expose a state as its value, so {Binding State.Value} shows empty and
    # writes nothing. Item templates bind plain records, where .Value can be a real property.
    if ($ctx.Mvux) {
        foreach ($m in $BindValueRx.Matches($text)) {
            if ($dataTpls | Where-Object { $m.Index -ge $_[0] -and $m.Index -lt $_[1] }) { continue }
            if (Test-Suppressed $text $m.Index 'bindvalue') { continue }
            $out.Add((New-Finding 'BINDVALUE' $text $m.Index "$($m.Groups[1].Value)=`"{Binding $($m.Groups[2].Value), Mode=TwoWay}`" on an MVUX model"))
        }
    }
    $out
}

function Get-CsIssues([string] $text, [string] $name, [string] $companionXaml, [string] $fullPath) {
    $out = [System.Collections.Generic.List[object]]::new()
    $script:IsXaml = $false
    $ctx = Get-ProjectContext $fullPath $text
    # Page and control code-behind only: App.xaml.cs wires app-level events (Frame.NavigationFailed
    # in the dotnet new templates), which is not view logic.
    if ($name -match '(?i)\.xaml\.cs$' -and $name -notmatch '(?i)^App\.xaml\.cs$') {
        foreach ($m in $HandlerRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'codebehind') { continue }
            $out.Add((New-Finding 'CODEBEHIND' $text $m.Index "handler $($m.Groups[1].Value)"))
        }
        foreach ($m in $VisRx.Matches($text)) {
            $target = $m.Groups[1].Value
            if ($target -match $OverlayName) {
                if (Test-Suppressed $text $m.Index 'overlay') { continue }
                $out.Add((New-Finding 'OVERLAY' $text $m.Index "$target.Visibility set in code-behind"))
            } else {
                if (Test-Suppressed $text $m.Index 'codebehind') { continue }
                $out.Add((New-Finding 'CODEBEHIND' $text $m.Index "$target.Visibility set in code-behind"))
            }
        }
        foreach ($m in $SizeRx.Matches($text)) {
            if (Test-Suppressed $text $m.Index 'responsive') { continue }
            $out.Add((New-Finding 'RESPONSIVE' $text $m.Index "breakpoint on $($m.Groups[1].Value) in code-behind"))
        }
    }
    if ($name -match $ModelName -and $name -notmatch '(?i)\.xaml\.cs$') {
        foreach ($m in @($PlatIfRx.Matches($text)) + @($PlatApiRx.Matches($text))) {
            if (Test-Suppressed $text $m.Index 'platformleak') { continue }
            $out.Add((New-Finding 'PLATFORMLEAK' $text $m.Index "platform branch on $($m.Groups[1].Value) in a model"))
        }
    }
    # C# Markup palette overrides (ColorPaletteOverride.cs) are the one place colours belong.
    if ($fullPath -notmatch $TestFile -and $name -notmatch '(?i)^Colou?r(Palette)?Override[^\\/]*\.cs$') {
        foreach ($m in $CsColorRx.Matches($text)) {
            # A dependency property's default (new PropertyMetadata(new SolidColorBrush(Colors.Black)))
            # is a fallback that bindings replace, not a colour the app shows.
            $ls = $text.LastIndexOf("`n", [Math]::Max(0, $m.Index - 1)) + 1
            if ($text.Substring($ls, $m.Index - $ls) -match '\bPropertyMetadata\s*\(') { continue }
            if (Test-Suppressed $text $m.Index 'cscolor') { continue }
            $lit = $m.Value.TrimEnd([char]40).Trim()
            $out.Add((New-Finding 'CSCOLOR' $text $m.Index "colour literal $lit"))
        }
        foreach ($m in $CsThickRx.Matches($text)) {
            if (-not (Test-NonZero $m.Groups[2].Value)) { continue }
            $rule = if ($m.Groups[1].Value -eq 'Thickness') { 'SPACING' } else { 'RADIUS' }
            if (Test-Suppressed $text $m.Index $rule.ToLower()) { continue }
            $out.Add((New-Finding $rule $text $m.Index "new $($m.Groups[1].Value)($($m.Groups[2].Value))"))
        }
    }
    $csTriggers = if ($ctx.Toolkit) { $AdaptiveCsRx.Matches($text) } else { @() }
    foreach ($m in $csTriggers) {
        $out.Add((New-Finding 'RESPONSIVE' $text $m.Index 'WinUI AdaptiveTrigger created in C#'))
    }
    # Tests may block on purpose; dev-path skipping misses Foo.Tests\ project folders.
    # Mock endpoints and fakes run as test plumbing, like test projects.
    $syncMatches = if ($fullPath -match $TestFile -or $fullPath -match '(?i)[\\/]Mocks?[\\/]') { @() } else { $SyncWaitRx.Matches($text) }
    foreach ($m in $syncMatches) {
        # Reading .Result after checking the task finished does not block.
        $look = $text.Substring([Math]::Max(0, $m.Index - 200), [Math]::Min(200, $m.Index))
        if ($m.Value -match '\.Result' -and $look -match 'IsCompleted|IsCompletedSuccessfully|RanToCompletion') { continue }
        if (Test-Suppressed $text $m.Index 'syncwait') { continue }
        $out.Add((New-Finding 'SYNCWAIT' $text $m.Index "blocking wait: $($m.Value.Trim())"))
    }
    foreach ($m in $ClassRx.Matches($text)) {
        $cls = $m.Groups[1].Value
        foreach ($entry in $BuiltinMap) {
            if ($cls -notmatch $entry[0]) { continue }
            if ($companionXaml -and $companionXaml -match [regex]::Escape($entry[2])) { break }
            if (-not (Test-Suppressed $text $m.Index 'builtin')) {
                $out.Add((New-Finding 'BUILTIN' $text $m.Index "$cls : $($m.Groups[2].Value) -> $($entry[1])"))
            }
            break
        }
    }
    $out
}

function Get-FileIssues([string] $file, [string] $text) {
    $leaf = Split-Path $file -Leaf
    if ((Get-ProjectContext $file).Maui) { return @() }
    $issues = if ($leaf -match '(?i)\.xaml$') { Get-XamlIssues $text $leaf $file }
    elseif ($leaf -match '(?i)\.cs$') {
        $companion = if ($file -match '(?i)\.xaml\.cs$') { $file -replace '(?i)\.cs$', '' } else { $null }
        $cx = if ($companion -and (Test-Path $companion)) { Get-Content $companion -Raw } else { $null }
        Get-CsIssues $text $leaf $cx $file
    }
    @($issues | Where-Object { $_ -and ($Strict -or $_.Rule -notin $StrictOnly) })
}

# ---------------------------------------------------------------- hook mode
if ($Hook) {
    try {
        $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
        $file = $payload.tool_input.file_path
        if (-not $file -or $file -notmatch '(?i)\.(xaml|cs)$') { exit 0 }
        # Write sends content, Edit new_string, MultiEdit edits[].new_string.
        $ti = $payload.tool_input
        $pieces = @(if ($ti.PSObject.Properties['edits'] -and $ti.edits) { $ti.edits | ForEach-Object { $_.new_string } }
                    elseif ($ti.PSObject.Properties['new_string']) { $ti.new_string }
                    else { $ti.content }) | Where-Object { $_ }
        if (-not $pieces) { exit 0 }

        # Lint the file as saved so context rules (ThemeDictionaries, NavigationBar, suppressions)
        # see the whole file, then keep only findings inside the added text.
        $full = if (Test-Path $file) { Get-Content $file -Raw } else { $null }
        $spans = @(foreach ($p in $pieces) { $s = if ($full) { $full.IndexOf($p) } else { -1 }; if ($s -ge 0) { , @($s, ($s + $p.Length)) } })
        if ($spans.Count -gt 0) {
            $issues = @(Get-FileIssues $file $full | Where-Object { $i = $_.Index; $spans | Where-Object { $i -ge $_[0] -and $i -lt $_[1] } })
        } else {
            $issues = @(Get-FileIssues $file ($pieces -join "`n"))
        }
        if ($issues.Count -eq 0) { exit 0 }

        $leaf = Split-Path $file -Leaf
        # Advice follows what the project references, so a plain WinUI app gets WinUI answers.
        $ctx = Get-ProjectContext $file $(if ($full) { $full } else { $pieces -join "`n" })
        $rules = $issues | Select-Object -ExpandProperty Rule -Unique
        $context = @(
            "xaml-semantic-lint: this edit to $leaf added $($issues.Count) semantic-bypass pattern(s):"
            ($issues | ForEach-Object { "- $($_.Rule): $($_.Detail)" })
            ($rules | ForEach-Object { "$_ fix: $(Get-Fix $_ $ctx)" })
            'A deliberate exception gets "xaml-lint: allow <rule> - reason" in a comment directly above the element; if a framework mechanism failed, the reason names it and how to reproduce it.'
            $(if ($issues | Where-Object Detail -match 'AdaptiveTrigger') { 'AdaptiveTrigger hits have no exception: an allow comment does not suppress them. Replace them.' })
        ) -join "`n"
        @{
            systemMessage      = "xaml-semantic-lint: $($issues.Count) hit(s) in $leaf ($($rules -join ', '))"
            hookSpecificOutput = @{ hookEventName = 'PostToolUse'; additionalContext = $context }
        } | ConvertTo-Json -Depth 4 -Compress
    } catch {
        # A lint must never break an edit.
    }
    exit 0
}

# ---------------------------------------------------------------- path mode
if (-not (Test-Path $Path)) { Write-Error "Path not found: $Path"; exit 2 }
# Get-Item expands 8.3 short names (PLATFO~1); Resolve-Path keeps them, which broke relative file names.
$root = (Get-Item -LiteralPath $Path).FullName.TrimEnd('\', '/')

$candidates = if ((Get-Item $root).PSIsContainer) {
    Get-ChildItem $root -Recurse -File -Include *.xaml, *.cs |
        Where-Object { $_.FullName -notmatch '[\\/](bin|obj|node_modules|\.git)[\\/]' -and $_.Name -notmatch '(?i)\.g(\.i)?\.cs$' }
} else { Get-Item $root }
$skipped = @($candidates | Where-Object { -not $IncludeDev -and $_.FullName.Substring($root.Length) -match $DevPath })
$files   = @($candidates | Where-Object { $skipped -notcontains $_ })

$all = [System.Collections.Generic.List[object]]::new()
$xamlTexts = @{}
foreach ($f in $files) {
    $text = Get-Content $f.FullName -Raw
    if (-not $text) { continue }
    if ($f.Name -match '(?i)\.xaml$') { $xamlTexts[$f.FullName] = $text }
    foreach ($i in (Get-FileIssues $f.FullName $text)) {
        $i | Add-Member File ($f.FullName.Substring($root.Length).TrimStart('\', '/'))
        $all.Add($i)
    }
}

# Info: TOKEN references and responsive mechanism mix.
$defined = [System.Collections.Generic.HashSet[string]]::new()
foreach ($t in $xamlTexts.Values) { foreach ($m in $BrushKeyRx.Matches($t)) { [void]$defined.Add($m.Groups[1].Value) } }
$tokenRefs = 0; $tokenKeys = @{}; $adaptive = 0; $responsive = 0; $retemplated = 0; $fontSizes = 0
foreach ($kv in $xamlTexts.GetEnumerator()) {
    $fontSizes  += $FontSizeRx.Matches($kv.Value).Count
    $adaptive    += $AdaptiveXamlRx.Matches($kv.Value).Count
    $retemplated += ([regex]::Matches($kv.Value, '<ControlTemplate\b')).Count
    $responsive += ([regex]::Matches($kv.Value, '\{\w+:Responsive\b')).Count
    if ($kv.Key -match $MaterialPal) { continue }
    foreach ($m in [regex]::Matches($kv.Value, '\{(?:ThemeResource|StaticResource)\s+([A-Za-z0-9_.]+Brush)\}')) {
        if ($defined.Contains($m.Groups[1].Value)) { $tokenRefs++; $tokenKeys[$m.Groups[1].Value] = 1 }
    }
}

$workarounds = 0
foreach ($f in $files) { $workarounds += @(Select-String -LiteralPath $f.FullName -Pattern 'WORKAROUND\(' -SimpleMatch:$false).Count }

$active = @($Gating | Where-Object { $Strict -or $_ -notin $StrictOnly })
$counts = [ordered]@{}
foreach ($r in $active) { $counts[$r] = @($all | Where-Object Rule -eq $r).Count }
$gatingTotal = ($counts.Values | Measure-Object -Sum).Sum
$profileName = if ($Strict) { 'strict' } else { 'recommended' }

if ($Json) {
    [pscustomobject]@{
        root = $root; profile = $profileName; files = $files.Count; skippedDev = $skipped.Count
        counts = $counts; tokenRefs = $tokenRefs; tokenKeys = $tokenKeys.Count; fontSizeLiterals = $fontSizes
        adaptiveTriggers = $adaptive; utuResponsive = $responsive; controlTemplates = $retemplated; workarounds = $workarounds
        suppressed = $script:Suppressed
        findings = @($all | Select-Object Rule, File, Line, Detail)
    } | ConvertTo-Json -Depth 4
} else {
    $meaning = @{}; foreach ($r in $Rulebook.rules) { $meaning[$r.id] = $r.title }
    "xaml-semantic-lint  $root  ($($files.Count) files, $($skipped.Count) dev/harness skipped, $profileName profile)"
    ''
    'Rule          Count   Supp  Meaning'
    '------------  -----  -----  -------'
    $supp = { param($r) $n = [int]$script:Suppressed[$r]; if ($n) { $n } else { '' } }
    foreach ($r in $Gating) {
        if ($counts.Contains($r)) { '{0,-12}  {1,5}  {2,5}  {3}' -f $r, $counts[$r], (& $supp $r), $meaning[$r] }
        else { '{0,-12}  {1,5}  {2,5}  {3}' -f $r, 'off', '', "$($meaning[$r]) (strict profile)" }
    }
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'XBINDMODE', @($all | Where-Object Rule -eq 'XBINDMODE').Count, (& $supp 'XBINDMODE'), 'info: x:Bind with no Mode outside item templates (OneTime default)'
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'TOKEN', $tokenRefs, '', "info: refs to $($tokenKeys.Count) app-defined brush keys"
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'FONTSIZE', $fontSizes, '', 'info: literal FontSize attributes (use a Material text style)'
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'UTURESP', $responsive, '', 'info: {utu:Responsive} uses'
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'TEMPLATE', $retemplated, '', 'info: app ControlTemplates (each should say why lightweight styling or BasedOn could not do it)'
    '{0,-12}  {1,5}  {2,5}  {3}' -f 'WORKAROUND', $workarounds, '', 'info: WORKAROUND(...) markers (each needs a gotcha entry with a repro)'
    $suppTotal = ($script:Suppressed.Values | Measure-Object -Sum).Sum
    if ($suppTotal) { ''; "Supp: $suppTotal hit(s) covered by allow comments. Each should name a framework limit with a repro." }
    foreach ($r in @($active) + @($InfoRules)) {
        $hits = @($all | Where-Object Rule -eq $r)
        if ($hits.Count -eq 0) { continue }
        ''
        "$r (top $Top files):"
        $hits | Group-Object File | Sort-Object Count -Descending | Select-Object -First $Top | ForEach-Object {
            $sample = ($_.Group | Select-Object -First 3 | ForEach-Object { "L$($_.Line) $($_.Detail)" }) -join '; '
            '  {0,4}  {1}  {2}' -f $_.Count, $_.Name, $sample
        }
    }
}

if ($gatingTotal -gt 0) { exit 1 }
exit 0
