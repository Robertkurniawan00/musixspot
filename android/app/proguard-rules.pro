# ── Anti-Decompilation & Advanced Obfuscation Rules ───────────────────
# Strip source filenames and flatten package hierarchy into unreadable root
-repackageclasses ''
-overloadaggressively
-allowaccessmodification

# Remove debugging logs and metadata in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# ── Flutter Core Wrapper ──────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ── AudioService & JustAudio Background Playback ──────────────────────
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# ── App Native Activity and Bridge ────────────────────────────────────
-keep class com.spotifyclone.spotify_music_player.** { *; }

# ── Play Core Suppressions ───────────────────────────────────────────
-dontwarn com.google.android.play.core.**
