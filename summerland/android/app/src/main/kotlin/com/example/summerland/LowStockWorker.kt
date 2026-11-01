package com.example.summerland

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL

/// Checks the backend for low-stock products even when the Flutter app is not
/// running.
///
/// The worker keeps the set of variants that were already low during its last
/// run. Only variants that are low now and were not low then produce a
/// notification, so simply opening the app does not re-alert existing
/// problems. When the set was never seeded, the run only records the current
/// state to avoid a burst of notifications on first install.
class LowStockWorker(
    appContext: Context,
    params: WorkerParameters,
) : Worker(appContext, params) {
    override fun doWork(): Result {
        val variants = try {
            fetchVariants()
        } catch (error: Exception) {
            return Result.retry()
        }

        val preferences = applicationContext.getSharedPreferences(
            PREFERENCES,
            Context.MODE_PRIVATE,
        )
        val hasBaseline = preferences.contains(KEY_KNOWN_LOW_STOCK)
        val knownIds = preferences.getStringSet(KEY_KNOWN_LOW_STOCK, emptySet())
            ?: emptySet()
        val lowStock = variants.filter { it.isLowStock }
        val currentIds = lowStock.map { it.id.toString() }.toSet()

        if (hasBaseline) {
            val arabic = isArabic()

            for (variant in lowStock) {
                if (variant.id.toString() in knownIds) continue

                LowStockNotifications.show(
                    applicationContext,
                    variant.id,
                    if (arabic) "تنبيه انخفاض المخزون" else "Low stock alert",
                    if (arabic) {
                        "مخزون ${variant.name} (${variant.model}) منخفض: " +
                            "تبقّى ${variant.quantity} فقط."
                    } else {
                        "${variant.name} (${variant.model}) is low on stock: " +
                            "${variant.quantity} left."
                    },
                )
            }
        }

        preferences.edit()
            .putStringSet(KEY_KNOWN_LOW_STOCK, currentIds)
            .apply()

        return Result.success()
    }

    private fun fetchVariants(): List<LowStockVariant> {
        val connection = URL("${baseUrl()}/api/ProductVariants")
            .openConnection() as HttpURLConnection

        try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.setRequestProperty("Accept", "application/json")

            val status = connection.responseCode

            if (status !in 200..299) {
                throw IllegalStateException("HTTP $status")
            }

            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val array = JSONArray(body)

            return (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val id = item.optInt("id", -1)

                if (id < 0) return@mapNotNull null

                LowStockVariant(
                    id = id,
                    name = item.optString("productName"),
                    model = item.optString("modelNumber"),
                    quantity = item.optInt("totalQuantity", 0),
                    isLowStock = item.optBoolean("isLowStock", false),
                )
            }
        } finally {
            connection.disconnect()
        }
    }

    /// Mirrors `ApiConfig`: the app stores its configured base URL in Flutter's
    /// shared preferences, so the background check calls the same server.
    private fun baseUrl(): String {
        val preferences = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val saved = preferences.getString("flutter.api.baseUrl", null)
        val value = if (saved.isNullOrBlank()) DEFAULT_BASE_URL else saved

        return value.trimEnd('/')
    }

    private fun isArabic(): Boolean {
        val preferences = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )

        return preferences.getString("flutter.settings.language", null) == "ar"
    }

    private data class LowStockVariant(
        val id: Int,
        val name: String,
        val model: String,
        val quantity: Int,
        val isLowStock: Boolean,
    )

    companion object {
        const val PREFERENCES = "low_stock_notifications"
        const val KEY_KNOWN_LOW_STOCK = "knownLowStockIds"
        private const val DEFAULT_BASE_URL = "http://summerland.runasp.net"
    }
}
