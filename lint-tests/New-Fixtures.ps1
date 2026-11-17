<#
  Writes the fixture tree for xaml-semantic-lint.ps1. Each folder under fixtures/ is one case:
  source files plus expected.json with the exact count per rule (unlisted rules expect 0).
  Re-run after editing a fixture here; Test-SemanticLint.ps1 runs them.
#>
$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot 'fixtures'
if (Test-Path $root) { Remove-Item $root -Recurse -Force }

$cases = [ordered]@{}

# ---------------------------------------------------------------- clean: every rule expects 0
$cases['clean'] = @{
  'expected.json' = '{}'
  'MainPage.xaml' = @'
<Page x:Class="App.MainPage"
      xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:utu="using:Uno.Toolkit.UI"
      xmlns:uen="using:Uno.Extensions.Navigation.UI">
  <Grid Background="{ThemeResource BackgroundBrush}">
    <utu:NavigationBar Content="Details">
      <utu:NavigationBar.MainCommand>
        <AppBarButton uen:Navigation.Request="-" />
      </utu:NavigationBar.MainCommand>
    </utu:NavigationBar>
    <utu:AutoLayout Spacing="{StaticResource Space200}" Padding="{StaticResource Space400Thickness}"
                    Orientation="{utu:Responsive Narrow=Vertical, Wide=Horizontal}">
      <utu:CardContentControl Style="{StaticResource FilledCardContentControlStyle}">
        <TextBlock Text="{x:Bind ViewModel.Title, Mode=OneWay}" Style="{StaticResource TitleMedium}" />
      </utu:CardContentControl>
      <Border Background="{ThemeResource OutlineVariantBrush}" Height="1" />
      <Border CornerRadius="0" Padding="0" />
      <PathIcon Data="{StaticResource ChevronIconData}" />
      <SymbolIcon Symbol="Home" />
      <Button Command="{x:Bind ViewModel.Save}" Content="Save" />
    </utu:AutoLayout>
  </Grid>
</Page>
'@
  'MainPage.xaml.cs' = @'
namespace App;
public sealed partial class MainPage : Page
{
    public MainPage() => this.InitializeComponent();
}
'@
  'Icons.xaml' = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <x:String x:Key="ChevronIconData">M8,4 L16,12 L8,20</x:String>
  <Path x:Key="Logo" Data="M0,0 L10,10" />
</ResourceDictionary>
'@
  'ColorPaletteOverride.xaml' = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Color x:Key="PrimaryColor">#5946D2</Color>
  <Thickness x:Key="Gutter">16</Thickness>
</ResourceDictionary>
'@
  'Styles.xaml' = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <ResourceDictionary.ThemeDictionaries>
    <ResourceDictionary x:Key="Light"><SolidColorBrush x:Key="AppAccentBrush" Color="{StaticResource PrimaryColor}" /></ResourceDictionary>
    <ResourceDictionary x:Key="Dark"><SolidColorBrush x:Key="AppAccentBrush" Color="{StaticResource PrimaryColor}" /></ResourceDictionary>
  </ResourceDictionary.ThemeDictionaries>
  <SolidColorBrush x:Key="ScrimFixedBrush" Color="{StaticResource PrimaryColor}" />
</ResourceDictionary>
'@
  'OrdersModel.cs' = @'
namespace App;
public partial record OrdersModel(IOrderService Orders)
{
    public async Task LoadAsync(CancellationToken ct) => await Orders.GetAsync(ct);
    public SKColor Tint(Color c) => new SKColor(c.R, c.G, c.B, c.A);
    public Color Clear => Colors.Transparent;
}
'@
}

# ---------------------------------------------------------------- card
$cases['card'] = @{
  'expected.json' = '{"CARD":1}'
  'Cards.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:utu="using:Uno.Toolkit.UI">
  <StackPanel>
    <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" />
    <!-- xaml-lint: allow card - image clip with a placeholder fill -->
    <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" />
    <utu:ShadowContainer Background="{ThemeResource SurfaceBrush}">
      <Border CornerRadius="{StaticResource Radius200CornerRadius}" Padding="{StaticResource Space400Thickness}" />
    </utu:ShadowContainer>
    <ContentControl>
      <ContentControl.Template>
        <ControlTemplate TargetType="ContentControl">
          <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" />
        </ControlTemplate>
      </ContentControl.Template>
    </ContentControl>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- hex
$cases['hex'] = @{
  'expected.json' = '{"HEX":2}'
  'Hex.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock Foreground="#FF0000" />
    <TextBlock>
      <TextBlock.Foreground><SolidColorBrush><SolidColorBrush.Color>#112233</SolidColorBrush.Color></SolidColorBrush></TextBlock.Foreground>
    </TextBlock>
    <!-- xaml-lint: allow hex - chart series colour, no role covers it -->
    <TextBlock Foreground="#00FF00" />
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- cscolor
$cases['cscolor'] = @{
  'expected.json' = '{"CSCOLOR":3}'
  'ChartRenderer.cs' = @'
namespace App;
public class ChartRenderer
{
    Color a = Color.FromArgb(255, 1, 2, 3);
    Color b = Colors.Red;
    string c = "#FF00FF";
    Color ok = Colors.Transparent;
    SKColor ok2(Color t) => new SKColor(t.R, t.G, t.B);
    // xaml-lint: allow cscolor - brand mark, fixed in both themes
    Color d = Colors.White;
}
'@
}

# ---------------------------------------------------------------- spacing
$cases['spacing'] = @{
  'expected.json' = '{"SPACING":5}'
  'Spacing.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Page.Resources>
    <Thickness x:Key="CardGap">4,0</Thickness>
    <Style x:Key="S" TargetType="Button"><Setter Property="Padding" Value="12" /></Style>
  </Page.Resources>
  <StackPanel Spacing="8">
    <TextBlock Margin="16" />
    <TextBlock Padding="0" />
    <!-- xaml-lint: allow spacing - optical nudge for the glyph baseline -->
    <TextBlock Margin="0,2,0,0" />
  </StackPanel>
</Page>
'@
  'Layout.cs' = @'
namespace App;
public class Layout { Thickness t = new Thickness(8); Thickness z = new Thickness(0); }
'@
}

# ---------------------------------------------------------------- radius
$cases['radius'] = @{
  'expected.json' = '{"RADIUS":4}'
  'Radius.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Page.Resources>
    <CornerRadius x:Key="Soft">4</CornerRadius>
    <Style x:Key="S" TargetType="Button"><Setter Property="CornerRadius" Value="6" /></Style>
  </Page.Resources>
  <StackPanel>
    <Border CornerRadius="8" />
    <Border CornerRadius="0" />
  </StackPanel>
</Page>
'@
  'Shape.cs' = @'
namespace App;
public class Shape { CornerRadius r = new CornerRadius(6); }
'@
}

# ---------------------------------------------------------------- tokentheme
$cases['tokentheme'] = @{
  'expected.json' = '{"TOKENTHEME":1}'
  'Brushes.xaml' = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <SolidColorBrush x:Key="AppAccentBrush" Color="{ThemeResource PrimaryColor}" />
  <SolidColorBrush x:Key="LogoInvariantBrush" Color="{ThemeResource PrimaryColor}" />
  <ResourceDictionary.ThemeDictionaries>
    <ResourceDictionary x:Key="Light"><SolidColorBrush x:Key="AppSurfaceBrush" Color="{StaticResource PrimaryColor}" /></ResourceDictionary>
  </ResourceDictionary.ThemeDictionaries>
</ResourceDictionary>
'@
}

# ---------------------------------------------------------------- backbar
$cases['backbar'] = @{
  'expected.json' = '{"BACKBAR":1}'
  'DetailPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:uen="using:Uno.Extensions.Navigation.UI">
  <Grid><Button uen:Navigation.Request="-" Content="Back" /></Grid>
</Page>
'@
  'OtherPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:utu="using:Uno.Toolkit.UI" xmlns:uen="using:Uno.Extensions.Navigation.UI">
  <utu:NavigationBar><utu:NavigationBar.MainCommand><AppBarButton uen:Navigation.Request="-" /></utu:NavigationBar.MainCommand></utu:NavigationBar>
</Page>
'@
}

# ---------------------------------------------------------------- codebehind + overlay
$cases['codebehind'] = @{
  'expected.json' = '{"CODEBEHIND":2,"OVERLAY":1}'
  'OrdersPage.xaml.cs' = @'
namespace App;
public sealed partial class OrdersPage : Page
{
    public OrdersPage() => this.InitializeComponent();
    private void OnSaveClick(object sender, RoutedEventArgs e) { }
    void Toggle() { EmptyState.Visibility = Visibility.Collapsed; FilterSheet.Visibility = Visibility.Visible; }
    // xaml-lint: allow codebehind - MediaPlayerElement transport glue, no Toolkit equivalent
    private void OnPositionChanged(object sender, RoutedEventArgs e) { }
}
'@
}

# ---------------------------------------------------------------- responsive (AdaptiveTrigger is unsuppressible)
$cases['responsive'] = @{
  'expected.json' = '{"RESPONSIVE":6}'
  'Shell.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:utu="using:Uno.Toolkit.UI" xmlns:win="using:Microsoft.UI.Xaml">
  <Page.Resources>
    <ControlTemplate x:Key="T" TargetType="ContentControl"><Grid><VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState><VisualState.StateTriggers>
      <AdaptiveTrigger MinWindowWidth="500" />
    </VisualState.StateTriggers></VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups></Grid></ControlTemplate>
  </Page.Resources>
  <Grid Padding="{utu:Responsive Narrow={StaticResource Space200Thickness}, Wide={StaticResource Space400Thickness}}">
    <VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState><VisualState.StateTriggers>
      <AdaptiveTrigger MinWindowWidth="720" />
      <!-- xaml-lint: allow responsive - trying to suppress -->
      <AdaptiveTrigger MinWindowWidth="900" />
      <win:AdaptiveTrigger MinWindowWidth="1000" />
    </VisualState.StateTriggers></VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
  </Grid>
</Page>
'@
  'Shell.xaml.cs' = @'
namespace App;
public sealed partial class Shell : Page
{
    void Apply() { if (ActualWidth < 600) { } }
}
'@
  'Triggers.cs' = @'
namespace App;
public static class Triggers { public static StateTriggerBase Wide() => new AdaptiveTrigger { MinWindowWidth = 720 }; }
'@
}

# ---------------------------------------------------------------- builtin
$cases['builtin'] = @{
  'expected.json' = '{"BUILTIN":1}'
  'StarRating.cs' = @'
namespace App;
public sealed class StarRating : Control { }
'@
  'ProgressMeter.xaml' = @'
<UserControl xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"><ProgressBar /></UserControl>
'@
  'ProgressMeter.xaml.cs' = @'
namespace App;
public sealed partial class ProgressMeter : UserControl { }
'@
}

# ---------------------------------------------------------------- icon
$cases['icon'] = @{
  'expected.json' = '{"ICON":3}'
  'Toolbar.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <PathIcon Data="M0,0 L10,10" />
    <Path><Path.Data><PathGeometry Figures="M0,0 L4,4" /></Path.Data></Path>
    <Viewbox><Canvas><Ellipse Width="4" Height="4" /></Canvas></Viewbox>
    <Path Data="{StaticResource ChevronIconData}" />
    <ContentControl><ContentControl.Template><ControlTemplate TargetType="ContentControl"><Path Data="M0,0 L2,2" /></ControlTemplate></ContentControl.Template></ContentControl>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- platformleak
$cases['platformleak'] = @{
  'expected.json' = '{"PLATFORMLEAK":2}'
  'CameraViewModel.cs' = @'
namespace App;
public partial class CameraViewModel
{
#if __ANDROID__
    const bool Native = true;
#endif
    bool Web => OperatingSystem.IsBrowser();
}
'@
}

# ---------------------------------------------------------------- syncwait
$cases['syncwait'] = @{
  'expected.json' = '{"SYNCWAIT":3}'
  'SyncService.cs' = @'
namespace App;
public class SyncService
{
    void A(Task task) => task.Wait();
    void B(Task t) => t.GetAwaiter().GetResult();
    int C() => LoadAsync().Result;
    async Task D() => await LoadAsync();
    Task<int> LoadAsync() => Task.FromResult(1);
}
'@
}

# ---------------------------------------------------------------- xbindmode (info)
$cases['xbindmode'] = @{
  'expected.json' = '{"XBINDMODE":1}'
  'ListPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <TextBlock Text="{x:Bind ViewModel.Title}" />
    <TextBlock Text="{x:Bind ViewModel.Count, Mode=OneWay}" />
    <Button Command="{x:Bind ViewModel.Save}" />
    <ListView>
      <ListView.ItemTemplate>
        <DataTemplate x:DataType="local:Order"><TextBlock Text="{x:Bind Customer.Name}" /></DataTemplate>
      </ListView.ItemTemplate>
    </ListView>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- card shapes that are not cards (uno-lint UNOL101 port)
$cases['card-shapes'] = @{
  'expected.json' = '{"CARD":1,"RADIUS":5}'
  'Shapes.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <Border CornerRadius="8,8,0,0" Background="{ThemeResource SurfaceBrush}" />
    <Border Width="40" Height="40" CornerRadius="20" Background="{ThemeResource PrimaryBrush}" />
    <Border Height="32" CornerRadius="16" Background="{ThemeResource SecondaryContainerBrush}" />
    <Border CornerRadius="12" Background="{ThemeResource SurfaceVariantBrush}">
      <TextBlock Text="New" />
    </Border>
    <Border CornerRadius="8" Background="{ThemeResource SurfaceBrush}">
      <StackPanel><TextBlock Text="Order 1042" /><TextBlock Text="3 items" /></StackPanel>
    </Border>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- suppression scope
$cases['suppression'] = @{
  'expected.json' = '{"CARD":1,"HEX":1,"ICON":1,"suppressed":{"CARD":1,"HEX":3,"SPACING":1,"CSCOLOR":1,"ICON":3}}'
  'Suppress.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <StackPanel>
    <!-- xaml-lint: allow card - avatar clip with a placeholder fill -->
    <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" />
    <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" />
    <!-- uno-lint: allow hex - chart series colour, no role covers it -->
    <TextBlock
        Text="Series A"
        Foreground="#FF0000" />
    <!-- xaml-lint: allow all - legacy brand block kept until the redesign -->
    <TextBlock Foreground="#00FF00" Margin="3" />
    <!--
      xaml-lint: allow hex - multi-line comment form
    -->
    <TextBlock Foreground="#0000FF" />
    <!-- xaml-lint: allow hex - meant for the next element only -->
    <StackPanel />
    <TextBlock Foreground="#ABCDEF" />
    <!-- xaml-lint: allow icon - illustration, the comment covers the whole Canvas -->
    <Canvas>
      <Path Data="M0,0 L10,10 Z" />
      <Canvas><Path Data="M2,2 L8,8 Z" /></Canvas>
      <Path Data="M4,4 L6,6 Z" />
    </Canvas>
    <Path Data="M9,9 L1,1 Z" />
  </StackPanel>
</Page>
'@
  'Brand.cs' = @'
namespace App;
public class Brand
{
    Color mark = Colors.Red; // xaml-lint: allow cscolor - logo mark, fixed in both themes
}
'@
}

# ---------------------------------------------------------------- BINDVALUE (uno-lint UNOL201 port): MVUX project
$cases['bindvalue'] = @{
  'expected.json' = '{"BINDVALUE":1}'
  'App.csproj' = @'
<Project Sdk="Uno.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net10.0-desktop</TargetFrameworks>
    <UnoFeatures>Material;Toolkit;MVUX;Navigation</UnoFeatures>
  </PropertyGroup>
</Project>
'@
  'SearchPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:mvux="using:Uno.Extensions.Reactive.UI">
  <StackPanel>
    <TextBox Text="{Binding City.Value, Mode=TwoWay}" />
    <TextBox Text="{Binding City, Mode=TwoWay}" />
    <mvux:FeedView Source="{Binding Reading}">
      <DataTemplate><TextBlock Text="{Binding Data.Value}" /></DataTemplate>
    </mvux:FeedView>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- BINDVALUE stays off without MVUX
$cases['bindvalue-mvvm'] = @{
  'expected.json' = '{}'
  'App.csproj' = @'
<Project Sdk="Uno.Sdk">
  <PropertyGroup><UnoFeatures>Material;Toolkit;Mvvm</UnoFeatures></PropertyGroup>
</Project>
'@
  'SettingsPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <Slider Value="{Binding Volume.Value, Mode=TwoWay}" />
</Page>
'@
}

# ---------------------------------------------------------------- project context: plain WinUI app (no Toolkit, no Uno.Themes)
$cases['plain-winui'] = @{
  'expected.json' = '{"HEX":1,"RESPONSIVE":1}'
  'App.csproj' = @'
<Project Sdk="Uno.Sdk">
  <PropertyGroup><UnoFeatures>SkiaRenderer;Mvvm</UnoFeatures></PropertyGroup>
</Project>
'@
  'MainPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Grid Padding="16">
    <VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState><VisualState.StateTriggers>
      <AdaptiveTrigger MinWindowWidth="720" />
    </VisualState.StateTriggers></VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
    <Border CornerRadius="8" Background="{ThemeResource CardBackgroundFillColorDefaultBrush}" Margin="12" />
    <TextBlock Foreground="#FF0000" />
  </Grid>
</Page>
'@
  'MainPage.xaml.cs' = @'
namespace App;
public sealed partial class MainPage : Page
{
    void Apply() { if (ActualWidth < 600) { } }
}
'@
}

# ---------------------------------------------------------------- Toolkit under another prefix
$cases['toolkit-prefix'] = @{
  'expected.json' = '{"RESPONSIVE":1}'
  'Page.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:toolkit="using:Uno.Toolkit.UI">
  <StackPanel Orientation="{toolkit:Responsive Narrow=Vertical, Wide=Horizontal}">
    <toolkit:ShadowContainer Background="{ThemeResource SurfaceBrush}">
      <Border CornerRadius="{StaticResource Radius200CornerRadius}" Padding="{StaticResource Space400Thickness}" />
    </toolkit:ShadowContainer>
    <VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState><VisualState.StateTriggers>
      <AdaptiveTrigger MinWindowWidth="720" />
    </VisualState.StateTriggers></VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
  </StackPanel>
</Page>
'@
}

# ---------------------------------------------------------------- file outside any project: only its xmlns counts
$cases['no-project'] = @{
  'expected.json' = '{"CARD":1}'
  'Loose.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:utu="using:Uno.Toolkit.UI">
  <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" Margin="16" />
</Page>
'@
}

# ---------------------------------------------------------------- features declared in Directory.Build.props
$cases['dirbuildprops'] = @{
  'expected.json' = '{"CARD":1,"SPACING":1}'
  'Directory.Build.props' = @'
<Project>
  <PropertyGroup><UnoFeatures>Material;Toolkit;Navigation</UnoFeatures></PropertyGroup>
</Project>
'@
  'App.csproj' = @'
<Project Sdk="Uno.Sdk"><PropertyGroup><TargetFrameworks>net10.0-desktop</TargetFrameworks></PropertyGroup></Project>
'@
  'Page.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <Border CornerRadius="{StaticResource Radius200CornerRadius}" Background="{ThemeResource SurfaceBrush}" Margin="16" />
</Page>
'@
}

# ---------------------------------------------------------------- Windows line endings (written as CRLF below)
$cases['crlf'] = @{
  'expected.json' = '{"HEX":1,"suppressed":{"HEX":1}}'
  'Crlf.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
  <StackPanel>
    <!-- xaml-lint: allow hex - chart series colour -->
    <TextBlock
        Text="A"
        Foreground="#FF0000" />
    <TextBlock Foreground="#00FF00" />
  </StackPanel>
</Page>
'@
}

# ================================================================ cases from the public corpus run (2026-11-17)
# Each reproduces a false positive found in Uno Platform's own apps and samples.

# uno.chefs: an image clip and a quantity badge are not cards; a list-item container is.
$cases['corpus-card'] = @{
  'expected.json' = '{"CARD":1}'
  'Recipes.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:utu="using:Uno.Toolkit.UI">
  <StackPanel>
    <Border utu:AutoLayout.PrimaryAlignment="Stretch"
            Background="{ThemeResource BackgroundBrush}"
            CornerRadius="{StaticResource Radius300CornerRadius}">
      <Image HorizontalAlignment="Center"
             Source="{Binding CookbookImages.SecondImage}"
             Stretch="UniformToFill" />
    </Border>
    <Border Background="{ThemeResource BackgroundBrush}" Padding="{StaticResource Space200Thickness}" CornerRadius="{StaticResource Radius100CornerRadius}">
      <TextBlock Text="{Binding Quantity}" Style="{StaticResource BodySmall}" />
    </Border>
    <Border Background="{ThemeResource SurfaceBrush}" CornerRadius="{StaticResource Radius100CornerRadius}">
      <utu:AutoLayout Spacing="{StaticResource Space200}">
        <TextBlock Text="{Binding Name}" />
        <TextBlock Text="{Binding Description}" />
      </utu:AutoLayout>
    </Border>
  </StackPanel>
</Page>
'@
}

# uno.chefs: Navigation.Request="-" in a ContentDialog closes it; it is not a back button.
$cases['corpus-dialog'] = @{
  'expected.json' = '{}'
  'CompletedDialog.xaml' = @'
<ContentDialog x:Class="App.CompletedDialog"
               xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
               xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
               xmlns:uen="using:Uno.Extensions.Navigation.UI">
  <Button Content="Done" uen:Navigation.Request="-" />
</ContentDialog>
'@
}

# workshops + uno.chefs: C# Markup palette overrides, Theme.Colors keys and dependency property defaults.
$cases['corpus-cscolor'] = @{
  'expected.json' = '{"CSCOLOR":1}'
  'ColorPaletteOverride.cs' = @'
namespace App;
public static class ColorPaletteOverride
{
    public static ResourceDictionary Build() => new ResourceDictionary()
        .Add<Color>(Theme.Colors.Background.Default.Key, "#FCFCFF", "#1A1C1E")
        .Add<Color>(Theme.Colors.Primary.Default.Key, Colors.Purple, Colors.Plum);
}
'@
  'ChartControl.xaml.cs' = @'
namespace App;
public sealed partial class ChartControl : UserControl
{
    public static readonly DependencyProperty CarbBrushProperty =
        DependencyProperty.Register("CarbBrush", typeof(SolidColorBrush), typeof(ChartControl), new PropertyMetadata(new SolidColorBrush(Colors.Black)));
    object Key => Theme.Colors.Surface.Default.Key;
    Color Highlight => Colors.Red;
}
'@
}

# Uno.Samples MvuxHowTos, ToDo, Commerce + uno.chefs: .Value is used on purpose outside two-way input.
$cases['corpus-bindvalue'] = @{
  'expected.json' = '{"BINDVALUE":1}'
  'App.csproj' = @'
<Project Sdk="Uno.Sdk"><PropertyGroup><UnoFeatures>Material;Toolkit;MVUX;Navigation</UnoFeatures></PropertyGroup></Project>
'@
  'PeoplePage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:uen="using:Uno.Extensions.Navigation.UI">
  <StackPanel DataContext="{Binding NewPerson.Value}">
    <Button Command="{Binding Save}" CommandParameter="{Binding NewPerson.Value}" />
    <Button uen:Navigation.Request="Filters" uen:Navigation.Data="{Binding Filter.Value, Mode=TwoWay}" />
    <Border Style="{Binding Entity.Value, Converter={StaticResource StyleConverter}}" />
    <TextBlock Text="{Binding CurrentProduct.Description.Value}" />
    <TextBox Text="{Binding Name.Value, Mode=TwoWay}" />
  </StackPanel>
</Page>
'@
}

# uno.ch9: a #if after a blank line is reported on the #if line, not the blank line above.
$cases['corpus-platformleak'] = @{
  'expected.json' = '{"PLATFORMLEAK":1,"lines":{"PLATFORMLEAK":[5]}}'
  'EpisodeViewModel.cs' = @'
namespace App;
public partial class EpisodeViewModel
{

#if !__WASM__
    bool CanDownload => true;
#endif
}
'@
}

# uno.ch9 + uno.chefs: .Result after a completion check, and mock endpoints, do not block the UI.
$cases['corpus-syncwait'] = @{
  'expected.json' = '{"SYNCWAIT":1}'
  'TaskNotifier.cs' = @'
namespace App;
public class TaskNotifier<T>
{
    public Task<T> Task { get; }
    public T Value => Task.Status == TaskStatus.RanToCompletion
        ? Task.Result
        : default;
    public bool Done => Task.IsCompleted && Task.Result is not null;
    void Flush(Task pending) => pending.Wait();
}
'@
  'Mocks/MockRecipeEndpoints.cs' = @'
namespace App.Mocks;
public class MockRecipeEndpoints
{
    string Read(HttpRequestMessage request) => request.Content.ReadAsStringAsync().Result;
}
'@
}

# Default (recommended) profile: no strict-only rules, ThemeDictionaries colours allowed.
$cases['profile-recommended'] = @{
  'expected.json' = '{"profile":"recommended","HEX":1,"RESPONSIVE":1}'
  'Page.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
      xmlns:utu="using:Uno.Toolkit.UI">
  <Page.Resources>
    <ResourceDictionary>
      <ResourceDictionary.ThemeDictionaries>
        <ResourceDictionary x:Key="Light"><SolidColorBrush x:Key="ProteinBrush">#159BFF</SolidColorBrush></ResourceDictionary>
        <ResourceDictionary x:Key="Dark"><SolidColorBrush x:Key="ProteinBrush">#7FC4FF</SolidColorBrush></ResourceDictionary>
      </ResourceDictionary.ThemeDictionaries>
    </ResourceDictionary>
  </Page.Resources>
  <StackPanel Margin="16">
    <Border CornerRadius="8" Background="{ThemeResource SurfaceBrush}" Padding="12" />
    <TextBlock Foreground="#FF0000" />
    <VisualStateManager.VisualStateGroups><VisualStateGroup><VisualState><VisualState.StateTriggers>
      <AdaptiveTrigger MinWindowWidth="720" />
    </VisualState.StateTriggers></VisualState></VisualStateGroup></VisualStateManager.VisualStateGroups>
  </StackPanel>
</Page>
'@
}

# Uno.Samples MauiEmbedding: .NET MAUI XAML is not WinUI XAML and is not linted.
$cases['corpus-maui'] = @{
  'expected.json' = '{}'
  'ToastControl.xaml' = @'
<?xml version="1.0" encoding="utf-8" ?>
<ContentView xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
             xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml">
  <Border Stroke="#D2D2D2" BackgroundColor="#FF0000" Padding="12" StrokeShape="RoundRectangle 8" />
</ContentView>
'@
}

# uno.gallery: lightweight styling in one control's Resources is not an app brush; a page-level one is.
# Fully transparent hex (#00FFFFFF) is a hit-test fill, not a colour.
$cases['corpus-lightweight'] = @{
  'expected.json' = '{"TOKENTHEME":1}'
  'StylingPage.xaml' = @'
<Page xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
      xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <Page.Resources>
    <SolidColorBrush x:Key="PageAccentBrush" Color="{ThemeResource PrimaryColor}" />
  </Page.Resources>
  <StackPanel>
    <Button Content="Overridden">
      <Button.Resources>
        <SolidColorBrush x:Key="ButtonBorderBrush" Color="{ThemeResource PrimaryColor}" />
      </Button.Resources>
    </Button>
    <Border BorderBrush="#00FFFFFF" Background="#0000" />
  </StackPanel>
</Page>
'@
}

# Uno.Samples GrialKitApp: a MAUI file opening with two processing instructions and a BOM.
$cases['corpus-maui-pi'] = @{
  'expected.json' = '{}'
  'Colors.xaml' = "$([char]0xFEFF)" + @'
<?xml version="1.0" encoding="UTF-8" ?>
<?xaml-comp compile="true" ?>
<ResourceDictionary
    xmlns="http://schemas.microsoft.com/dotnet/2021/maui"
    xmlns:x="http://schemas.microsoft.com/winfx/2009/xaml">
  <Color x:Key="Blue100Accent">#3E8EED</Color>
</ResourceDictionary>
'@
}

# Uno.Samples MauiEmbedding: a whole .NET MAUI project (UseMaui) is skipped, C# included.
$cases['corpus-maui-project'] = @{
  'expected.json' = '{}'
  'Controls.MauiControls.csproj' = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><UseMaui>true</UseMaui></PropertyGroup>
</Project>
'@
  'SeriesSelection.xaml.cs' = @'
namespace Controls;
public partial class SeriesSelection
{
    object Brush => new SolidColorBrush(Color.FromArgb("#74BD6F"));
    void OnTapped(object sender, EventArgs e) { Legend.Visibility = Visibility.Collapsed; }
}
'@
}

# Uno.Samples: converters keyed *Brush, StaticResource aliases and theme seed colours are not app colours.
$cases['corpus-resources'] = @{
  'expected.json' = '{"TOKENTHEME":1,"HEX":1}'
  'App.xaml' = @'
<Application xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:utu="using:Uno.Toolkit.UI"
             xmlns:conv="using:App.Converters">
  <Application.Resources>
    <ResourceDictionary>
      <utu:ThemeColors PrimarySeed="#0D6E6E" SecondarySeed="#3B82F6"
                       TertiarySeed="#F59E0B" />
      <conv:HexColorToBrushConverter x:Key="HexToBrush" />
      <StaticResource x:Key="GridLinesBrush" ResourceKey="SystemControlHighlightListLowBrush" />
      <SolidColorBrush x:Key="FlowInfoBrush" Color="#8A8A8E" />
    </ResourceDictionary>
  </Application.Resources>
</Application>
'@
}

# dotnet new unoapp (Uno.Templates 7.0.22, blank preset): App.xaml.cs wires Frame.NavigationFailed;
# app-level wiring is not page code-behind. A page handler next to it still counts.
$cases['template-app'] = @{
  'expected.json' = '{"CODEBEHIND":1}'
  'App.xaml.cs' = @"
namespace TemplateApp;
public partial class App : Application
{
    void OnNavigationFailed(object sender, NavigationFailedEventArgs e)
    {
        throw new InvalidOperationException(`$"Failed to load {e.SourcePageType.FullName}: {e.Exception}");
    }
}
"@
  'MainPage.xaml.cs' = @"
namespace TemplateApp;
public sealed partial class MainPage : Page
{
    private void OnRefreshClick(object sender, RoutedEventArgs e) { }
}
"@
}

# Strict profile: colours belong in the palette override only, ThemeDictionaries included.
$cases['hex-themedict-strict'] = @{
  'expected.json' = '{"HEX":1}'
  'Brushes.xaml' = @'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <ResourceDictionary.ThemeDictionaries>
    <ResourceDictionary x:Key="Light"><SolidColorBrush x:Key="ProteinBrush">#159BFF</SolidColorBrush></ResourceDictionary>
  </ResourceDictionary.ThemeDictionaries>
</ResourceDictionary>
'@
}

# Cases that test rules gated on Uno Toolkit / Uno.Themes / Navigation get a project that has them.
$fullProject = @'
<Project Sdk="Uno.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net10.0-desktop</TargetFrameworks>
    <UnoFeatures>Material;Toolkit;Navigation</UnoFeatures>
  </PropertyGroup>
</Project>
'@
foreach ($k in @($cases.Keys)) {
  if ($k -in 'no-project', 'plain-winui', 'clean', 'corpus-maui-project') { continue }
  if (-not $cases[$k].ContainsKey('App.csproj')) { $cases[$k]['App.csproj'] = $fullProject }
}

foreach ($case in $cases.GetEnumerator()) {
  $dir = Join-Path $root $case.Key
  New-Item -ItemType Directory $dir -Force | Out-Null
  foreach ($f in $case.Value.GetEnumerator()) {
    $value = $f.Value -replace "`r`n", "`n"
    if ($case.Key -eq 'crlf') { $value = $value -replace "`n", "`r`n" }
    $target = Join-Path $dir $f.Key
    New-Item -ItemType Directory (Split-Path $target -Parent) -Force | Out-Null
    Set-Content -LiteralPath $target -Value $value -NoNewline
  }
}
"Wrote $($cases.Count) fixture cases to $root"
