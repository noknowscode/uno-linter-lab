namespace App;
public partial class EpisodeViewModel
{

#if !__WASM__
    bool CanDownload => true;
#endif
}