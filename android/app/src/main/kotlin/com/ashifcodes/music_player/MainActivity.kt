package com.ashifcodes.music_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.DocumentsContract
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream

private const val TAG = "TunefrostMainActivity"

class MainActivity : AudioServiceActivity() {
    // The file the current `VIEW` intent asked us to open. Captured before
    // Flutter builds so a cold start ("open with" while the app is closed)
    // can be replayed to Dart once it is ready to receive it.
    private var pendingUri: String? = null

    // Set up in [configureFlutterEngine]; used to push files opened while the
    // app is already running.
    private var channel: MethodChannel? = null

    // Channel for Storage Access Framework (SAF) file operations on the
    // user-chosen download folder (a persisted `content://` tree URI).
    private var safChannel: MethodChannel? = null

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

        // SAF channel for writing downloaded audio to the user's chosen folder.
        val safChannel: MethodCallHandler = { call, result ->
            when (call.method) {
                "safCopyFile" -> handleSafCopyFile(call, result)
                "safExists" -> handleSafExists(call, result)
                "safDelete" -> handleSafDelete(call, result)
                else -> result.notImplemented()
            }
        }
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SAF_CHANNEL,
        )
        ch.setMethodCallHandler(safChannel)
        this.safChannel = ch
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

    // ---------- SAF download-folder helpers ----------

    private fun handleSafCopyFile(call: MethodCall, result: Result) {
        val treeUriString = call.argument<String>("treeUri") ?: run {
            result.error("arg", "missing treeUri", null)
            return
        }
        val tempPath = call.argument<String>("tempPath") ?: run {
            result.error("arg", "missing tempPath", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: run {
            result.error("arg", "missing fileName", null)
            return
        }
        try {
            copyFileToSafTree(treeUriString, tempPath, fileName)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "SAF copy to $treeUriString/$fileName failed", e)
            result.error("saf_write", e.message ?: e.toString(), null)
        }
    }

    private fun handleSafExists(call: MethodCall, result: Result) {
        val treeUriString = call.argument<String>("treeUri") ?: run {
            result.error("arg", "missing treeUri", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: run {
            result.error("arg", "missing fileName", null)
            return
        }
        try {
            result.success(fileExistsInSafTree(treeUriString, fileName))
        } catch (e: Exception) {
            Log.e(TAG, "SAF exists check $treeUriString/$fileName failed", e)
            result.error("saf_exists", e.message ?: e.toString(), null)
        }
    }

    private fun handleSafDelete(call: MethodCall, result: Result) {
        val treeUriString = call.argument<String>("treeUri") ?: run {
            result.error("arg", "missing treeUri", null)
            return
        }
        val fileName = call.argument<String>("fileName") ?: run {
            result.error("arg", "missing fileName", null)
            return
        }
        try {
            deleteFileInSafTree(treeUriString, fileName)
            result.success(null)
        } catch (e: Exception) {
            Log.e(TAG, "SAF delete $treeUriString/$fileName failed", e)
            result.error("saf_delete", e.message ?: e.toString(), null)
        }
    }

    /** Returns the URI of [fileName] inside the SAF tree, or null if absent. */
    private fun findChildDocumentUri(treeUri: Uri, fileName: String): Uri? {
        val contentResolver = this.contentResolver
        val rootDocId =
            DocumentsContract.getTreeDocumentId(treeUri)
                ?: throw SecurityException("Cannot resolve document ID for SAF tree URI.")
        val childDocumentsUri =
            DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, rootDocId)

        val projection = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
        )

        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                childDocumentsUri,
                projection,
                null,
                null,
                null,
            )
            if (cursor != null) {
                while (cursor.moveToNext()) {
                    val name =
                        cursor.getString(
                            cursor.getColumnIndexOrThrow(
                                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                            ),
                        )
                    if (name == fileName) {
                        val docId =
                            cursor.getString(
                                cursor.getColumnIndexOrThrow(
                                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                                ),
                            )
                        return DocumentsContract.buildDocumentUriUsingTree(
                            treeUri,
                            docId,
                        )
                    }
                }
            }
            null
        } finally {
            cursor?.close()
        }
    }

    /** Copies [tempPath] into the SAF tree as [fileName], overwriting if present. */
    private fun copyFileToSafTree(treeUriString: String, tempPath: String, fileName: String) {
        val treeUri = Uri.parse(treeUriString)
        val contentResolver = this.contentResolver

        // Delete existing file if present so we can recreate it.
        val existingUri = findChildDocumentUri(treeUri, fileName)
        if (existingUri != null) {
            DocumentsContract.deleteDocument(contentResolver, existingUri)
        }

        // Root document of the tree acts as the parent for the new document.
        val rootDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val rootDocUri =
            DocumentsContract.buildDocumentUriUsingTree(treeUri, rootDocId)
        val newUri =
            DocumentsContract.createDocument(
                contentResolver,
                rootDocUri,
                "audio/*",
                fileName,
            ) ?: throw SecurityException("Failed to create document $fileName in SAF tree.")

        val outputStream: OutputStream? = contentResolver.openOutputStream(newUri)
        if (outputStream == null) {
            throw SecurityException(
                "Content resolver refused to open an output stream for $fileName.",
            )
        }
        val input = FileInputStream(File(tempPath))
        try {
            input.copyTo(outputStream)
        } finally {
            input.close()
            outputStream.close()
        }
    }

    /** Whether [fileName] exists in the SAF tree. */
    private fun fileExistsInSafTree(treeUriString: String, fileName: String): Boolean {
        val treeUri = Uri.parse(treeUriString)
        return findChildDocumentUri(treeUri, fileName) != null
    }

    /** Deletes [fileName] from the SAF tree if present. */
    private fun deleteFileInSafTree(treeUriString: String, fileName: String) {
        val treeUri = Uri.parse(treeUriString)
        val existingUri = findChildDocumentUri(treeUri, fileName)
        if (existingUri != null) {
            try {
                DocumentsContract.deleteDocument(
                    this.contentResolver,
                    existingUri,
                )
            } catch (_: Exception) {
                // Best effort.
            }
        }
    }

    companion object {
        private const val OPEN_MEDIA_CHANNEL =
            "com.ashifcodes.music_player/open_media"
        private const val SAF_CHANNEL = "com.ashifcodes.music_player/saf"
    }
}
