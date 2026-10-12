package com.ashifcodes.music_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    // The file the current `VIEW` intent asked us to open. Captured before
    // Flutter starts so a cold start ("open with" while the app is closed)
    // can be replayed to Dart once it is ready to receive it.
    private var pendingUri: String? = null

    // Set up in [configureFlutterEngine]; used to push files opened while the
    // app is already running.
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Read the launch intent before Flutter builds: this is the only point
        // at which a cold-start handoff is still available.
        pendingUri = viewUri(intent)
        super.onCreate(savedInstanceState)
        // audio_service creates this channel as IMPORTANCE_LOW, which can
        // suppress lock-screen media controls on Android 14+. It skips
        // creation when the channel already exists, so pre-create it here
        // as IMPORTANCE_DEFAULT before any notification is posted.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "com.ashifcodes.music_player.channel.audio",
                "Music playback",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            // Media playback notifications must be silent: with
            // IMPORTANCE_DEFAULT the system would otherwise play the default
            // notification sound on every state change.
            channel.setSound(null, null)
            channel.enableVibration(false)
            channel.setBypassDnd(false)
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            OPEN_MEDIA_CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart asks once at startup for the file we were launched with.
                "getInitialUri" -> {
                    result.success(pendingUri)
                    pendingUri = null
                }

                else -> result.notImplemented()
            }
        }
        this.channel = channel
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // `singleTop` means a second "open with" reuses this instance instead
        // of creating a new one, so the file arrives here.
        val uri = viewUri(intent) ?: return
        pendingUri = uri
        channel?.invokeMethod("open", uri)
    }

    // The `content://` / `file://` URI of a `VIEW` intent, or null when this
    // intent did not ask us to open anything.
    private fun viewUri(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        return intent.data?.toString()
    }

    companion object {
        private const val OPEN_MEDIA_CHANNEL =
            "com.ashifcodes.music_player/open_media"
    }
}
