namespace App;
public partial record OrdersModel(IOrderService Orders)
{
    public async Task LoadAsync(CancellationToken ct) => await Orders.GetAsync(ct);
    public SKColor Tint(Color c) => new SKColor(c.R, c.G, c.B, c.A);
    public Color Clear => Colors.Transparent;
}