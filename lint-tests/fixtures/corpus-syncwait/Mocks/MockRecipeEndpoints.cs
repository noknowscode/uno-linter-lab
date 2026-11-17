namespace App.Mocks;
public class MockRecipeEndpoints
{
    string Read(HttpRequestMessage request) => request.Content.ReadAsStringAsync().Result;
}