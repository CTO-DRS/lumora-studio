package com.ctodrs.lumora

import android.annotation.TargetApi
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter

/**
 * Flutter host activity plus a tiny on-device diagnostics bridge
 * ("lumora/diagnostics"). Nothing is uploaded anywhere: the Dart side copies
 * what it gets into the local error log shown in Settings.
 */
class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        CrashRecorder.install(applicationContext)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "takeJavaCrash" -> result.success(CrashRecorder.take(applicationContext))
                    "exitReasons" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                            result.success(exitReasons())
                        } else {
                            result.success(emptyList<Map<String, Any?>>())
                        }
                    }
                    "deviceInfo" -> result.success(deviceInfo())
                    else -> result.notImplemented()
                }
            } catch (error: Throwable) {
                result.error("DIAGNOSTICS_ERROR", error.toString(), null)
            }
        }
    }

    private fun deviceInfo(): Map<String, Any?> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mem = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mem)
        return mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "sdk" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "abis" to Build.SUPPORTED_ABIS.joinToString(","),
            "totalMemMb" to (mem.totalMem / (1024 * 1024)),
            "availMemMb" to (mem.availMem / (1024 * 1024)),
            "lowMemory" to mem.lowMemory,
            "memoryClassMb" to am.memoryClass,
            "largeMemoryClassMb" to am.largeMemoryClass,
        )
    }

    /** Why the previous runs of this app ended (Android 11+). */
    @TargetApi(Build.VERSION_CODES.R)
    private fun exitReasons(): List<Map<String, Any?>> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return am.getHistoricalProcessExitReasons(packageName, 0, 5).map { info ->
            mapOf(
                "timestamp" to info.timestamp,
                "reason" to reasonName(info.reason),
                "status" to info.status,
                "description" to info.description,
                "importance" to info.importance,
                "pssKb" to info.pss,
                "rssKb" to info.rss,
            )
        }
    }

    @TargetApi(Build.VERSION_CODES.R)
    private fun reasonName(reason: Int): String =
        when (reason) {
            ApplicationExitInfo.REASON_CRASH -> "CRASH (Java/Kotlin exception)"
            ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE (native signal)"
            ApplicationExitInfo.REASON_ANR -> "ANR (not responding)"
            ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY (killed by the system)"
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
            ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
            ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
            ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
            ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
            ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
            ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
            ApplicationExitInfo.REASON_OTHER -> "OTHER"
            else -> "UNKNOWN($reason)"
        }

    companion object {
        private const val CHANNEL = "lumora/diagnostics"
    }
}

/**
 * Writes the stack trace of an uncaught JVM exception (for example a
 * NoClassDefFoundError thrown by a plugin) to a private file before the
 * process dies, so the next launch can show it in the error log.
 */
object CrashRecorder {
    private const val FILE_NAME = "lumora_java_crash.txt"

    @Volatile
    private var installed = false

    fun install(context: Context) {
        if (installed) return
        installed = true
        val dir = context.filesDir
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val trace = StringWriter()
                error.printStackTrace(PrintWriter(trace))
                File(dir, FILE_NAME).writeText(
                    "time=${System.currentTimeMillis()} thread=${thread.name}\n$trace",
                )
            } catch (ignored: Throwable) {
                // Never let the recorder hide the original crash.
            }
            if (previous != null) {
                previous.uncaughtException(thread, error)
            } else {
                android.os.Process.killProcess(android.os.Process.myPid())
                kotlin.system.exitProcess(10)
            }
        }
    }

    /** Returns the recorded crash (if any) and deletes it. */
    fun take(context: Context): String? {
        val file = File(context.filesDir, FILE_NAME)
        if (!file.exists()) return null
        val text = file.readText()
        file.delete()
        return text
    }
}
