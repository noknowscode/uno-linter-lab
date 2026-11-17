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