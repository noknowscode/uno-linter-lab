namespace App;
public partial class CameraViewModel
{
#if __ANDROID__
    const bool Native = true;
#endif
    bool Web => OperatingSystem.IsBrowser();
}