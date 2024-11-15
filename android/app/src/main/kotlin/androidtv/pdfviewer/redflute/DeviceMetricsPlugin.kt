package androidtv.pdfviewer.redflute  // Fix package name to match the directory structure

import android.app.ActivityManager
import android.content.Context
import android.os.Process
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.math.max
import kotlin.math.min

class DeviceMetricsPlugin: FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "androidtv.pdfviewer.redflute/device_metrics")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableMemory" -> result.success(getAvailableMemory())
            "getCpuUsage" -> result.success(getCpuUsage())
            else -> result.notImplemented()
        }
    }

    private fun getAvailableMemory(): Double {
        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val memoryInfo = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        return (memoryInfo.availMem / (1024.0 * 1024.0)) // Convert to MB
    }

    private fun getCpuUsage(): Double {
        try {
            val pid = Process.myPid()
            val statFile = File("/proc/$pid/stat")
            if (!statFile.exists()) return -1.0

            val stats = statFile.readText().split(" ")
            val utime = stats[13].toLong()
            val stime = stats[14].toLong()
            val total = utime + stime

            Thread.sleep(100) // Wait a bit to measure difference

            val newStats = statFile.readText().split(" ")
            val newUtime = newStats[13].toLong()
            val newStime = newStats[14].toLong()
            val newTotal = newUtime + newStime

            val cpuUsage = ((newTotal - total) / 1.0) * 10.0
            return max(0.0, min(cpuUsage, 100.0))  // Now using kotlin.math.min
        } catch (e: Exception) {
            return -1.0
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}