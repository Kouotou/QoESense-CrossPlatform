package io.github.kouotou.qoesense.capture

import android.annotation.SuppressLint
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.location.Location
import android.media.AudioManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.os.Build
import android.os.SystemClock
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import io.github.kouotou.qoesense.MeasurementStatus
import io.github.kouotou.qoesense.SessionTypeMessage
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/** Port of the reference telemetry/ConnectivitySampler.kt. */
class ConnectivitySampler(private val context: Context) {
    data class Reading(val connectionType: String?, val isRoaming: Boolean?, val status: MeasurementStatus)

    fun readCurrent(): Reading {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = cm.activeNetwork ?: return Reading(null, null, MeasurementStatus.UNAVAILABLE)
        val caps = cm.getNetworkCapabilities(network) ?: return Reading(null, null, MeasurementStatus.UNAVAILABLE)
        val type = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WIFI"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "CELLULAR"
            else -> "OTHER"
        }
        // NET_CAPABILITY_NOT_ROAMING exists from API 28; null before (reference behaviour).
        val roaming = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING)
        } else {
            null
        }
        return Reading(type, roaming, MeasurementStatus.OK)
    }
}

/**
 * Port of the reference telemetry/ThroughputSampler.kt: device-wide rx+tx bytes per second
 * from TrafficStats, averaged since the previous call. The first call has no baseline and
 * reports UNAVAILABLE. Addition: the averaging window, measured on the monotonic clock rather
 * than the wall clock the reference used.
 */
class ThroughputSampler {
    data class Reading(val bytesPerSecond: Long?, val windowMs: Long?, val status: MeasurementStatus)

    private var lastTotalBytes: Long? = null
    private var lastElapsedMs: Long? = null

    fun sample(): Reading {
        val now = SystemClock.elapsedRealtime()
        val rx = TrafficStats.getTotalRxBytes()
        val tx = TrafficStats.getTotalTxBytes()
        if (rx == TrafficStats.UNSUPPORTED.toLong() || tx == TrafficStats.UNSUPPORTED.toLong()) {
            return Reading(null, null, MeasurementStatus.NOT_SUPPORTED)
        }
        val total = rx + tx
        val prevBytes = lastTotalBytes
        val prevTime = lastElapsedMs
        lastTotalBytes = total
        lastElapsedMs = now
        if (prevBytes == null || prevTime == null) return Reading(null, null, MeasurementStatus.UNAVAILABLE)
        val windowMs = now - prevTime
        if (windowMs <= 0) return Reading(null, null, MeasurementStatus.UNAVAILABLE)
        val deltaBytes = (total - prevBytes).coerceAtLeast(0)
        return Reading((deltaBytes * 1000.0 / windowMs).toLong(), windowMs, MeasurementStatus.OK)
    }
}

/**
 * Port of the reference telemetry/LocationSampler.kt: a one-shot fused location at balanced
 * power, bounded on both the request and the await, because on some OEMs
 * getCurrentLocation() from a service never calls back. Additions: the fix's own age (fused
 * can return a recent cached fix), and why there was no fix.
 */
class LocationSampler(context: Context) {
    data class Reading(
        val latitude: Double?,
        val longitude: Double?,
        /** Kotlin's shortest Float representation, widened without float noise (DATA_CONTRACT §3 row 23). */
        val accuracyMeters: Double?,
        val ageMs: Long?,
        val status: MeasurementStatus,
    )

    private val appContext = context.applicationContext
    private val client = LocationServices.getFusedLocationProviderClient(appContext)

    @SuppressLint("MissingPermission") // guarded below
    suspend fun sampleOnce(timeoutMs: Long, staleAfterMs: Long): Reading {
        if (!PermissionUtils.hasForegroundLocation(appContext)) return empty(MeasurementStatus.PERMISSION_DENIED)
        val cancellation = CancellationTokenSource()
        // Outer null = our timeout fired; Outcome.location null = the OS answered "no fix".
        val outcome: Outcome = withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { cont ->
                cont.invokeOnCancellation { cancellation.cancel() }
                val request = CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
                    .setDurationMillis(timeoutMs)
                    .build()
                client.getCurrentLocation(request, cancellation.token)
                    .addOnSuccessListener { if (cont.isActive) cont.resume(Outcome(it, failed = false)) }
                    .addOnFailureListener { if (cont.isActive) cont.resume(Outcome(null, failed = true)) }
            }
        } ?: return empty(MeasurementStatus.TIMEOUT)
        if (outcome.failed) return empty(MeasurementStatus.FAILED)
        // The fused provider gives up at setDurationMillis with a null fix: no fix available.
        val location = outcome.location ?: return empty(MeasurementStatus.UNAVAILABLE)
        val ageMs = ((SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000L).coerceAtLeast(0)
        return Reading(
            latitude = location.latitude,
            longitude = location.longitude,
            accuracyMeters = if (location.hasAccuracy()) location.accuracy.toString().toDouble() else null,
            ageMs = ageMs,
            status = if (ageMs > staleAfterMs) MeasurementStatus.STALE else MeasurementStatus.OK,
        )
    }

    private fun empty(status: MeasurementStatus) = Reading(null, null, null, null, status)

    private class Outcome(val location: Location?, val failed: Boolean)
}

/**
 * Port of the reference telemetry/AppUsageMonitor.kt: classification, the monitored package
 * lists and the WhatsApp-call heuristic (MODE_IN_COMMUNICATION) are unchanged.
 *
 * **One deliberate fix (documented in docs/PHASE3_ANDROID.md):** the reference only looked at
 * the last 10 s of usage events, so an app that had been in the foreground for longer than
 * 10 s was reported as "no app", which at a 60 s cadence is most of the time. This version
 * keeps the last foreground package across calls and applies every event since the previous
 * call. A package stays "current" until another app comes to the foreground or it moves to
 * the background.
 */
class AppUsageMonitor(private val context: Context) {
    data class Session(val packageName: String?, val sessionType: SessionTypeMessage, val status: MeasurementStatus)

    private var currentPackage: String? = null
    private var lastQueryEndMs: Long? = null

    fun currentForegroundSession(): Session {
        if (!PermissionUtils.hasUsageAccess(context)) {
            currentPackage = null
            lastQueryEndMs = null
            return Session(null, SessionTypeMessage.NONE, MeasurementStatus.PERMISSION_DENIED)
        }
        val pkg = trackForeground() ?: return Session(null, SessionTypeMessage.NONE, MeasurementStatus.UNAVAILABLE)
        val type = when {
            pkg in MonitoredApps.VIDEO_CONFERENCING_PACKAGES -> SessionTypeMessage.VIDEO_CONFERENCING
            pkg == MonitoredApps.WHATSAPP_PACKAGE && isAudioCallActive() -> SessionTypeMessage.VIDEO_CONFERENCING
            pkg in MonitoredApps.SOCIAL_MEDIA_PACKAGES -> SessionTypeMessage.SOCIAL_MEDIA
            else -> SessionTypeMessage.NONE
        }
        return Session(pkg, type, MeasurementStatus.OK)
    }

    private fun trackForeground(): String? {
        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        // First call: the reference 10 s window. Afterwards: everything since the previous
        // call, capped at 1 h so a long gap can't make one query huge.
        val begin = (lastQueryEndMs ?: (end - INITIAL_WINDOW_MS)).coerceAtLeast(end - MAX_WINDOW_MS)
        val events = usm.queryEvents(begin, end)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            @Suppress("DEPRECATION") // MOVE_TO_* equal ACTIVITY_RESUMED/PAUSED; kept for API < 29
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> currentPackage = event.packageName
                UsageEvents.Event.MOVE_TO_BACKGROUND -> if (event.packageName == currentPackage) currentPackage = null
            }
        }
        lastQueryEndMs = end
        return currentPackage
    }

    private fun isAudioCallActive(): Boolean =
        (context.getSystemService(Context.AUDIO_SERVICE) as AudioManager).mode == AudioManager.MODE_IN_COMMUNICATION

    private companion object {
        const val INITIAL_WINDOW_MS = 10_000L
        const val MAX_WINDOW_MS = 60 * 60 * 1000L
    }
}

/** Port of the reference MonitoredApps, unchanged. */
object MonitoredApps {
    val SOCIAL_MEDIA_PACKAGES = setOf("com.whatsapp", "com.facebook.katana", "com.instagram.android")
    val VIDEO_CONFERENCING_PACKAGES = setOf(
        "us.zoom.videomeetings",
        "com.google.android.apps.meetings",
        "com.google.android.apps.classroom",
    )
    const val WHATSAPP_PACKAGE = "com.whatsapp"
}
