package com.follow.clashx

import android.app.Application
import android.content.Context
import android.os.Build
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FlClashXApplication : Application() {

    companion object {
        private const val TAG = "FlClashXApp"
        private lateinit var instance: FlClashXApplication

        fun getAppContext(): Context = instance.applicationContext

        fun logCrash(tag: String, message: String, throwable: Throwable? = null) {
            try {
                val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())
                val sw = StringWriter()
                throwable?.printStackTrace(PrintWriter(sw))
                val entry = "[$timestamp] [$tag] $message${if (throwable != null) "\n$sw" else ""}\n"
                Log.e(tag, message, throwable)
                // Write to same file as Dart CrashLogger for unified log viewing
                val logDir = instance.applicationContext.getExternalFilesDir(null)
                    ?: instance.applicationContext.filesDir
                val logFile = File(logDir, "flclashr_debug.log")
                logFile.appendText(entry)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write crash log: ${e.message}")
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        setupCrashHandler()
        Log.d(TAG, "FlClashXApplication started, device: ${Build.MODEL} API ${Build.VERSION.SDK_INT}")
    }

    private fun setupCrashHandler() {
        val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            logCrash(
                tag = "FATAL",
                message = "Uncaught exception on thread '${thread.name}'",
                throwable = throwable
            )
            // Give it time to flush
            Thread.sleep(500)
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
}
