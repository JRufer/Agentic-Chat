package com.example.agentic_chat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import android.app.ActivityManager
import android.content.Context

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.agentic_chat/hardware_info"

    companion object {
        init {
            try {
                System.loadLibrary("litertlm_jni")
            } catch (e: Exception) {
                // Library might be loaded by the plugin itself
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getHardwareInfo") {
                val info = mutableMapOf<String, Any>()
                
                // Get RAM info
                val actManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val memInfo = ActivityManager.MemoryInfo()
                actManager.getMemoryInfo(memInfo)
                val totalRamGB = memInfo.totalMem / (1024 * 1024 * 1024)
                
                // Get CPU cores
                val cores = Runtime.getRuntime().availableProcessors()
                
                info["ramGB"] = totalRamGB
                info["cpuCores"] = cores
                info["model"] = Build.MODEL
                
                result.success(info)
            } else {
                result.notImplemented()
            }
        }
    }
}
