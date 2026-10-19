package com.pulyn.pulyn_app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ponte de log: o logger do Dart manda cada linha para o Logcat (tag "PulynApp").
        // Em release o print do Dart não aparece no adb logcat, então escrevemos direto aqui.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pulyn/logs")
            .setMethodCallHandler { call, result ->
                if (call.method != "log") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val level = call.argument<String>("level") ?: "info"
                val message = call.argument<String>("message") ?: ""
                when (level) {
                    "error", "fatal" -> Log.e(TAG, message)
                    "warning" -> Log.w(TAG, message)
                    "debug", "trace" -> Log.d(TAG, message)
                    else -> Log.i(TAG, message)
                }
                result.success(null)
            }
    }

    companion object {
        private const val TAG = "PulynApp"
    }
}
