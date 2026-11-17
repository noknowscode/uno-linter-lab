namespace App;
public static class ColorPaletteOverride
{
    public static ResourceDictionary Build() => new ResourceDictionary()
        .Add<Color>(Theme.Colors.Background.Default.Key, "#FCFCFF", "#1A1C1E")
        .Add<Color>(Theme.Colors.Primary.Default.Key, Colors.Purple, Colors.Plum);
}