namespace App;
public static class Triggers { public static StateTriggerBase Wide() => new AdaptiveTrigger { MinWindowWidth = 720 }; }