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