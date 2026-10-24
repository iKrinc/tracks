package com.krinc.tracks

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// FragmentActivity is required by local_auth for the biometric prompt.
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var initialIntent: Intent? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tracks/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "initial" -> {
                        val intent = initialIntent
                        initialIntent = null
                        if (intent == null) result.success(null)
                        else read(intent) { result.success(it) }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // A recreated activity (rotation, dark mode) must not re-deliver.
        if (savedInstanceState == null) initialIntent = intent
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        read(intent) { payload -> if (payload != null) channel?.invokeMethod("shared", payload) }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    /**
     * Turns a share into {text, files: [{path, mime, name}], error}.
     * Never throws: another app's broken or revoked URI must not take
     * Tracks down, it just becomes an error message.
     */
    private fun read(intent: Intent, done: (Map<String, Any?>?) -> Unit) {
        val action = intent.action
        // Reopened from Recents: the share was already handled.
        val fromHistory = intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (fromHistory || (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE)) {
            done(null)
            return
        }
        io.execute {
            val payload: Map<String, Any?> = try {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                val files = mutableListOf<Map<String, Any?>>()
                var failed = 0
                for ((i, uri) in streams(intent).withIndex()) {
                    try {
                        files += copy(uri, intent.type, i)
                    } catch (e: Throwable) {
                        failed++
                    }
                }
                mapOf(
                    "text" to text,
                    "files" to files,
                    "error" to if (failed > 0) "Couldn't open $failed shared file(s)" else null,
                )
            } catch (e: Throwable) {
                mapOf("text" to null, "files" to emptyList<Any>(), "error" to (e.message ?: e.javaClass.simpleName))
            }
            // A share with nothing in it (e.g. a task relaunched without
            // its extras) is not worth a message.
            val empty = payload["text"] == null &&
                (payload["files"] as? List<*>).isNullOrEmpty() &&
                payload["error"] == null
            main.post { done(if (empty) null else payload) }
        }
    }

    @Suppress("DEPRECATION")
    private fun streams(intent: Intent): List<Uri> = try {
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            }?.filterNotNull() ?: emptyList()
        } else {
            val uri = if (Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            }
            listOfNotNull(uri)
        }
    } catch (e: Throwable) {
        emptyList()
    }

    /** Copies a shared stream into the app cache (capped at 25 MB). */
    private fun copy(uri: Uri, fallbackMime: String?, index: Int): Map<String, Any?> {
        val mime = try { contentResolver.getType(uri) } catch (e: Throwable) { null } ?: fallbackMime
        val name = displayName(uri) ?: "shared_$index"
        val dir = File(cacheDir, "shared").apply { mkdirs() }
        val safeName = name.replace(Regex("""[^\w.\-]"""), "_")
        val out = File(dir, "${System.currentTimeMillis()}_${index}_$safeName")
        val input = contentResolver.openInputStream(uri) ?: throw IllegalStateException("No stream")
        input.use { src ->
            out.outputStream().use { dst ->
                val buf = ByteArray(64 * 1024)
                var total = 0L
                while (true) {
                    val n = src.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > MAX_BYTES) {
                        out.delete()
                        throw IllegalStateException("File too large")
                    }
                    dst.write(buf, 0, n)
                }
            }
        }
        return mapOf("path" to out.absolutePath, "mime" to mime, "name" to name)
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    } catch (e: Throwable) {
        uri.lastPathSegment
    }

    companion object {
        private const val MAX_BYTES = 25L * 1024 * 1024
    }
}
