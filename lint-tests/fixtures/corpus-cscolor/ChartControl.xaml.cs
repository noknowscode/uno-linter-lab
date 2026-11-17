namespace App;
public sealed partial class ChartControl : UserControl
{
    public static readonly DependencyProperty CarbBrushProperty =
        DependencyProperty.Register("CarbBrush", typeof(SolidColorBrush), typeof(ChartControl), new PropertyMetadata(new SolidColorBrush(Colors.Black)));
    object Key => Theme.Colors.Surface.Default.Key;
    Color Highlight => Colors.Red;
}