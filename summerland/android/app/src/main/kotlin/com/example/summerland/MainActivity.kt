package com.example.summerland

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "summerland/low_stock_notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        scheduleBackgroundChecks()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        LowStockNotifications.ensureChannel(this)
                        LowStockNotifications.requestPermission(this)
                        scheduleBackgroundChecks()
                        result.success(null)
                    }

                    "showLowStock" -> {
                        val id = call.argument<Int>("id") ?: 0
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        LowStockNotifications.show(this, id, title, body)
                        result.success(null)
                    }

                    "rememberLowStock" -> {
                        val ids = call.argument<List<*>>("ids")
                            ?.mapNotNull { (it as? Number)?.toInt() }
                            ?.map { it.toString() }
                            ?.toSet()
                            ?: emptySet()

                        applicationContext
                            .getSharedPreferences(
                                LowStockWorker.PREFERENCES,
                                Context.MODE_PRIVATE,
                            )
                            .edit()
                            .putStringSet(LowStockWorker.KEY_KNOWN_LOW_STOCK, ids)
                            .apply()
                        result.success(null)
                    }

                    "scheduleCheck" -> {
                        scheduleImmediateCheck()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /// Registers the 15-minute periodic check (Android's minimum interval for
    /// background work). KEEP means opening the app again does not reset the
    /// schedule.
    private fun scheduleBackgroundChecks() {
        val request = PeriodicWorkRequestBuilder<LowStockWorker>(
            15,
            TimeUnit.MINUTES,
        )
            .setConstraints(networkConstraints())
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            PERIODIC_WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    /// Asks for an early check right after a sale, so the alert still arrives if
    /// the app is killed before the foreground flow finishes.
    private fun scheduleImmediateCheck() {
        val request = OneTimeWorkRequestBuilder<LowStockWorker>()
            .setConstraints(networkConstraints())
            .build()

        WorkManager.getInstance(this).enqueueUniqueWork(
            IMMEDIATE_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    private fun networkConstraints(): Constraints {
        return Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "low_stock_periodic_check"
        private const val IMMEDIATE_WORK_NAME = "low_stock_immediate_check"
    }
}
