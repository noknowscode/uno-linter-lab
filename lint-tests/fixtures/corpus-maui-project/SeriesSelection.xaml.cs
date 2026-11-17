namespace Controls;
public partial class SeriesSelection
{
    object Brush => new SolidColorBrush(Color.FromArgb("#74BD6F"));
    void OnTapped(object sender, EventArgs e) { Legend.Visibility = Visibility.Collapsed; }
}