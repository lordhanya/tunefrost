# audio_service / just_audio are driven by manifest entries, method channels
# and framework callbacks that R8 cannot trace — stripping them breaks the
# media notification and lock-screen controls in release builds.
-keep class com.ryanheise.** { *; }
-keep class androidx.media.session.** { *; }
-keep class androidx.media.common.** { *; }
