# Uno Platform code rules for coding agents

Generated from `rules.json`. Apply a rule only when the project has what it needs (check `UnoFeatures` in the .csproj or Directory.Build.props). A deliberate exception gets `xaml-lint: allow <rule> - reason` in a comment directly above it.

## Every project

### BINDVALUE (needs MVUX)

The MVUX bindable proxy already exposes the state's value; a two-way binding to .Value on an input does not write back.

Don't:

```xaml
<TextBox Text="{Binding City.Value, Mode=TwoWay}" />
```

Do:

```xaml
<TextBox Text="{Binding City, Mode=TwoWay}" />
```

Fix: bind the state itself on a two-way input: {Binding State, Mode=TwoWay}. The MVUX proxy already exposes the value. Inside a FeedView template bind {Binding Data.X}.

### BUILTIN

A re-implemented control misses the theme, accessibility and fixes the shipped one gets.

Don't:

```cs
public sealed class StarRating : Control { }
```

Do:

```cs
public sealed class OrderSummary : Control { }
```

Fix: use the platform/Toolkit control named above with lightweight styling before writing a custom control; then Windows Community Toolkit 8.x.

### CSCOLOR

Colours chosen in code skip the theme entirely and never change with light/dark.

Don't:

```cs
public class Legend
{
    Color Overdue => Colors.Red;
}
```

Do:

```cs
public class Legend
{
    Brush Overdue => (Brush)Application.Current.Resources["ErrorBrush"];
}
```

Fix: read the colour from theme resources (a Brush dependency property bound with {ThemeResource ...Brush}, or a lookup keyed on ActualTheme) and redraw on ActualThemeChanged.

### HEX

A literal colour does not follow light/dark or a brand change; the theme's palette is the one place colours belong.

Don't:

```xaml
<TextBlock Text="Overdue" Foreground="#D32F2F" />
```

Do:

```xaml
<TextBlock Text="Overdue" Foreground="{ThemeResource ErrorBrush}" />
```

Fix: a theme brush ({ThemeResource ...Brush}) from the app's theme, or a colour defined once in the theme's colour override file. A literal colour does not follow light/dark or brand changes.

With material: a Material role brush (PrimaryBrush, OnSurfaceBrush, SurfaceContainerHighBrush, OutlineVariantBrush, ErrorBrush...). The only colours an app defines live in its ColorPaletteOverride file; brand colour goes there. Status and chart colours map to Primary/Secondary/Tertiary/Error and their containers.

### ICON

Hand-drawn icons drift in size and stroke and cannot be swapped as a set.

Don't:

```xaml
<PathIcon Data="M12,2 L22,22 L2,22 Z" />
```

Do:

```xaml
<SymbolIcon Symbol="Favorite" />
```

Fix: SymbolIcon/FontIcon on the Fluent symbol font, or keyed path data from one open icon set (Material Symbols, Fluent System Icons) in Icons.xaml via PathIcon Data="{StaticResource ...}". Never hand-draw icons. Illustrations get "xaml-lint: allow icon - illustration".

### PLATFORMLEAK

Platform branches in models make them untestable on other targets and scatter platform logic.

Don't:

```cs
public partial class CameraViewModel
{
    bool CanScan => OperatingSystem.IsAndroid();
}
```

Do:

```cs
public partial class CameraViewModel(IScannerService scanner)
{
    bool CanScan => scanner.IsAvailable;
}
```

Fix: move the branch into a platform service (interface in shared code, implementation per head or in a Platforms/ partial) and inject it; models stay platform-neutral.

### RESPONSIVE

Two breakpoint systems in one app drift apart; width logic in code-behind cannot be previewed or tested.

Don't:

```xaml
<VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState>
  <VisualState.StateTriggers><AdaptiveTrigger MinWindowWidth="720" /></VisualState.StateTriggers>
</VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
```

Do:

```xaml
<StackPanel Orientation="{utu:Responsive Narrow=Vertical, Wide=Horizontal}" />
```

Fix: move the breakpoint into XAML: a VisualStateManager state with an AdaptiveTrigger (or add Uno Toolkit and use {utu:Responsive}). Never compare widths in code-behind or keep width flags on a view model.

With toolkit: breakpoints are always {utu:Responsive} in XAML for a value, utu:ResponsiveView when the whole template changes (custom thresholds via a utu:ResponsiveLayout resource). No WinUI AdaptiveTrigger (not suppressible), never code-behind, never width flags on a view model.

### SYNCWAIT

Blocking on a task freezes the UI thread and can deadlock.

Don't:

```cs
public class OrderLoader
{
    string Load(HttpClient http) => http.GetStringAsync("/orders").Result;
}
```

Do:

```cs
public class OrderLoader
{
    async Task<string> Load(HttpClient http) => await http.GetStringAsync("/orders");
}
```

Fix: await the task. If the caller cannot be async (constructor, property), start the load from a command or MVUX feed instead of blocking.

### TOKENTHEME

A brush defined once outside ThemeDictionaries keeps its light-mode value in dark mode.

Don't:

```xaml
<Page.Resources>
  <SolidColorBrush x:Key="AccentBrush" Color="{StaticResource BrandColor}" />
</Page.Resources>
```

Do:

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

Fix: use a theme role brush; else define the key per theme in ThemeDictionaries; name it *Invariant/*OnDark/*OnLight/*Fixed only when its ground is fixed in both themes.

### XBINDMODE

x:Bind defaults to OneTime, so a value that changes later never shows.

Don't:

```xaml
<TextBlock Text="{x:Bind ViewModel.Title}" />
```

Do:

```xaml
<TextBlock Text="{x:Bind ViewModel.Title, Mode=OneWay}" />
```

Fix: x:Bind is OneTime by default: add Mode=OneWay for values that change, or a comment saying OneTime is intended.

## Strict profile (opt-in)

### BACKBAR (needs Uno Toolkit)

A hand-built back button misses the platform back gesture and the shared app bar layout.

Don't:

```xaml
<Button uen:Navigation.Request="-" Content="Back" />
```

Do:

```xaml
<utu:NavigationBar Content="Details">
  <utu:NavigationBar.MainCommand><AppBarButton uen:Navigation.Request="-" /></utu:NavigationBar.MainCommand>
</utu:NavigationBar>
```

Fix: utu:NavigationBar with a MainCommand AppBarButton; back navigation and the Android back gesture come with it.

### CARD (needs Uno Toolkit)

A hand-drawn card ignores the theme's card styles and states, so every card in the app drifts a little differently.

Don't:

```xaml
<Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}">
  <StackPanel><TextBlock Text="Order 1042" /><TextBlock Text="3 items" /></StackPanel>
</Border>
```

Do:

```xaml
<utu:CardContentControl Style="{StaticResource FilledCardContentControlStyle}">
  <StackPanel><TextBlock Text="Order 1042" /><TextBlock Text="3 items" /></StackPanel>
</utu:CardContentControl>
```

Fix: utu:CardContentControl (Filled/Outlined/ElevatedCardContentControlStyle) + lightweight keys (CardCornerRadius, CardPadding, <Variant>CardContentBackground/BorderBrush).

### CODEBEHIND

Logic in code-behind cannot be tested and spreads: one workaround gets copied to every page.

Don't:

```cs
public sealed partial class OrdersPage : Page
{
    private void OnSaveClick(object sender, RoutedEventArgs e) { }
}
```

Do:

```cs
public sealed partial class OrdersPage : Page
{
    public OrdersPage() => this.InitializeComponent();
}
```

Fix: commands on the model (ICommand), VisualStateManager states driven by model state, or Visibility bound to the model.

With toolkit: utu:CommandExtensions.Command, commands on the model, utu:VisualStateManagerExtensions.States bound to model state, or Visibility bound to the model.

### OVERLAY

Hand-toggled overlays miss focus handling, dismissal and back navigation.

Don't:

```cs
public sealed partial class SearchPage : Page
{
    void ShowFilters() => FilterSheet.Visibility = Visibility.Visible;
}
```

Do:

```cs
public sealed partial class SearchPage : Page
{
    public SearchPage() => this.InitializeComponent();
}
```

Fix: a Flyout or ContentDialog, or Visibility bound to model state; filter state lives in the model.

With navigation: uen:Navigation.Request="!Route" to a Page (opens as a flyout) with a DrawerFlyoutPresenter style; filter state lives in the model.

### RADIUS (needs An Uno.Themes theme)

Literal radii cannot be rescaled from the theme and drift between controls.

Don't:

```xaml
<Button Content="Save" CornerRadius="8" />
```

Do:

```xaml
<Button Content="Save" CornerRadius="{StaticResource Radius200CornerRadius}" />
```

Fix: Uno.Themes Radius* tokens: {StaticResource Radius200CornerRadius}. Rescale with DefaultCornerRadius on the theme.

### SPACING (needs An Uno.Themes theme)

Literal spacing cannot be rescaled from the theme and drifts between screens.

Don't:

```xaml
<StackPanel Margin="16" Spacing="8" />
```

Do:

```xaml
<StackPanel Margin="{StaticResource Space400Thickness}" Spacing="{StaticResource Space200}" />
```

Fix: Uno.Themes Space* tokens: {StaticResource Space400Thickness} for Margin/Padding, {StaticResource Space200} for Spacing. Rescale the whole app with DefaultSpacing on the theme.
