namespace App;
public class SyncService
{
    void A(Task task) => task.Wait();
    void B(Task t) => t.GetAwaiter().GetResult();
    int C() => LoadAsync().Result;
    async Task D() => await LoadAsync();
    Task<int> LoadAsync() => Task.FromResult(1);
}