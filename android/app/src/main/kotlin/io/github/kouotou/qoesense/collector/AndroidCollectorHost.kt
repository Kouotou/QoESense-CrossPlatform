package io.github.kouotou.qoesense.collector

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.github.kouotou.qoesense.AndroidCollectorApi
import io.github.kouotou.qoesense.CapturedSampleMessage
import io.github.kouotou.qoesense.CollectorStatusMessage
import io.github.kouotou.qoesense.MeasurementStatus
import io.github.kouotou.qoesense.SurveyAnswerMessage
import io.github.kouotou.qoesense.capture.AppUsageMonitor
import io.github.kouotou.qoesense.capture.CellularTelemetrySource
import io.github.kouotou.qoesense.capture.ConnectivitySampler
import io.github.kouotou.qoesense.capture.LocationSampler
import io.github.kouotou.qoesense.capture.ThroughputSampler
import io.github.kouotou.qoesense.survey.SurveyPresenter
import io.github.kouotou.qoesense.upload.UploadScheduler
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

/**
 * The Android side of the channel. One instance per Flutter engine: the UI engine, the
 * collector service's headless engine, or an upload worker's engine.
 *
 * [captureSample] is the reference TelemetrySampler.captureSample, except RTT (shared Dart):
 * cellular, connectivity, foreground app and throughput synchronously, then the bounded
 * location wait. Each engine has its own samplers, as in the reference, where the Status
 * test button and the service each owned a TelemetrySampler.
 */
class AndroidCollectorHost(
    context: Context,
    private val onUploadFinished: ((success: Boolean, uploadedRows: Long) -> Unit)? = null,
) : AndroidCollectorApi {

    private val appContext = context.applicationContext
    private val prefs = CollectorPrefs(appContext)
    private val cellular = CellularTelemetrySource(appContext)
    private val connectivity = ConnectivitySampler(appContext)
    private val usage = AppUsageMonitor(appContext)
    private val throughput = ThroughputSampler()
    private val location = LocationSampler(appContext)

    fun stop() = cellular.stop()

    override suspend fun captureSample(locationTimeoutMs: Long, staleAfterMs: Long): CapturedSampleMessage = coroutineScope {
        val radio = cellular.readCurrent(staleAfterMs)
        val net = connectivity.readCurrent()
        val session = usage.currentForegroundSession()
        val tput = throughput.sample()
        val loc = async { location.sampleOnce(locationTimeoutMs, staleAfterMs) }.await()

        val statuses = mapOf(
            "RADIO" to radio.radioStatus,
            "CQI" to radio.cqiStatus,
            "PHYSICAL_CHANNEL" to radio.physicalChannelStatus,
            "NETWORK_TYPE" to radio.networkTypeStatus,
            "CONNECTIVITY" to net.status,
            "THROUGHPUT" to tput.status,
            "FOREGROUND_APP" to session.status,
            "LOCATION" to loc.status,
        )
        val gaps = setOf(MeasurementStatus.NOT_SUPPORTED, MeasurementStatus.PERMISSION_DENIED, MeasurementStatus.RESTRICTED)
        val info = AppInfoReader.read(appContext)

        CapturedSampleMessage(
            rsrp = radio.rsrp?.toLong(),
            rsrq = radio.rsrq?.toLong(),
            rssnr = radio.rssnr?.toLong(),
            timingAdvance = radio.timingAdvance?.toLong(),
            cellIdentityHash = radio.cellIdentityHash,
            trackingAreaCode = radio.trackingAreaCode?.toLong(),
            signalStrengthLevel = radio.signalStrengthLevel?.toLong(),
            radioStatus = radio.radioStatus,
            cellInfoAgeMs = radio.cellInfoAgeMs,
            cqi = radio.cqi?.toLong(),
            cqiStatus = radio.cqiStatus,
            cellBandwidthKhz = radio.cellBandwidthKhz?.toLong(),
            downlinkChannelNumber = radio.downlinkChannelNumber?.toLong(),
            uplinkChannelNumber = radio.uplinkChannelNumber?.toLong(),
            physicalChannelStatus = radio.physicalChannelStatus,
            networkType = radio.networkType,
            networkTypeStatus = radio.networkTypeStatus,
            connectionType = net.connectionType,
            isRoaming = net.isRoaming,
            connectivityStatus = net.status,
            throughputBytesPerSecond = tput.bytesPerSecond,
            throughputWindowMs = tput.windowMs,
            throughputStatus = tput.status,
            foregroundAppPackage = session.packageName,
            appSessionType = session.sessionType,
            foregroundAppStatus = session.status,
            latitude = loc.latitude,
            longitude = loc.longitude,
            locationAccuracyMeters = loc.accuracyMeters,
            locationAgeMs = loc.ageMs,
            locationStatus = loc.status,
            capabilitySet = statuses.filterValues { it !in gaps }.keys.toList(),
            deviceModel = Build.MODEL ?: "unknown",
            osSdkInt = Build.VERSION.SDK_INT.toLong(),
            osVersion = Build.VERSION.RELEASE ?: "${Build.VERSION.SDK_INT}",
            appId = info.appId,
            appVersion = info.versionName,
            appBuild = info.versionCode,
        )
    }

    override fun setCollectionEnabled(enabled: Boolean) {
        prefs.collectionEnabled = enabled
        if (enabled) {
            CollectorService.start(appContext)
            UploadScheduler.schedule(appContext)
        } else {
            CollectorService.stop(appContext)
            UploadScheduler.cancel(appContext)
        }
    }

    override fun status() = CollectorStatusMessage(
        collectionEnabled = prefs.collectionEnabled,
        serviceRunning = CollectorService.isRunning,
        lastUploadMs = prefs.lastUploadMs,
    )

    override fun presentSurvey(triggerType: String) = SurveyPresenter.present(appContext, triggerType)

    override fun pendingSurveyAnswers(): List<SurveyAnswerMessage> = prefs.pendingAnswers()

    override fun acknowledgeSurveyAnswers(responseIds: List<String>) = prefs.acknowledge(responseIds)

    override fun uploadRunFinished(success: Boolean, uploadedRows: Long) {
        if (success && uploadedRows > 0) prefs.lastUploadMs = System.currentTimeMillis()
        onUploadFinished?.invoke(success, uploadedRows)
    }

    override fun openSystemSettings(target: String) {
        val pkg = Uri.parse("package:${appContext.packageName}")
        val intent = when (target) {
            "usageAccess" -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "overlay" -> Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, pkg)
            // Same as the reference onboarding: the direct exemption request.
            @Suppress("BatteryLife")
            "batteryOptimization" -> Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, pkg)
            else -> Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, pkg)
        }.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
    }

    override fun requestUploadNow() = UploadScheduler.runOnce(appContext)

    override fun recordConsent(timestampMs: Long) {
        prefs.consentMs = timestampMs
    }
}

/** versionName / versionCode / application ID, read once per call (cheap). */
object AppInfoReader {
    data class Info(val appId: String, val versionName: String, val versionCode: Long)

    fun read(context: Context): Info {
        val pm = context.packageManager
        val pi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(context.packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            pm.getPackageInfo(context.packageName, 0)
        }
        val code = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            pi.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            pi.versionCode.toLong()
        }
        return Info(context.packageName, pi.versionName ?: "unknown", code)
    }
}
