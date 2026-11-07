package io.github.kouotou.qoesense

import android.Manifest
import android.app.AppOpsManager
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.telephony.TelephonyManager

/**
 * Explicit, honest capability report for this Android device: one [Availability] per field
 * group, derived from hardware features, API level, and *granted* permissions - never assumed.
 *
 * Requirements mirror the reference app's capture sources (../QoESense telemetry/):
 * - Cell signal + identity come from getAllCellInfo(), which needs ACCESS_FINE_LOCATION.
 * - Network type comes from getDataNetworkType(), which needs READ_PHONE_STATE (API 24+).
 * - CQI exists from API 29; PhysicalChannelConfig needs carrier privileges that participant
 *   devices don't have, so it reports RESTRICTED unless the app actually holds them.
 * - Foreground app / call detection need the PACKAGE_USAGE_STATS app-op.
 *
 * Phase 1 only *reports*; it doesn't request permissions or capture anything. The manifest
 * doesn't declare the runtime permissions yet, so they report PERMISSION_MISSING here.
 */
class AndroidCapabilityReporter(private val context: Context) : TelemetryHostApi {

    override suspend fun getCapabilityReport(): CapabilityReportMessage {
        val pm = context.packageManager
        val hasTelephony = pm.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
        val fineLocation = granted(Manifest.permission.ACCESS_FINE_LOCATION)
        val anyLocation = fineLocation || granted(Manifest.permission.ACCESS_COARSE_LOCATION)
        val phoneState = granted(Manifest.permission.READ_PHONE_STATE)
        val usageAccess = hasUsageAccess()

        val radioSignal = when {
            !hasTelephony -> Availability.UNSUPPORTED_ON_PLATFORM
            fineLocation -> Availability.AVAILABLE
            else -> Availability.PERMISSION_MISSING
        }
        val cqi = if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) Availability.UNSUPPORTED_ON_PLATFORM else radioSignal
        val physicalChannel = when {
            !hasTelephony || Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> Availability.UNSUPPORTED_ON_PLATFORM
            hasCarrierPrivileges() -> Availability.AVAILABLE
            else -> Availability.RESTRICTED
        }
        val rat = when {
            !hasTelephony -> Availability.UNSUPPORTED_ON_PLATFORM
            phoneState -> Availability.AVAILABLE
            else -> Availability.PERMISSION_MISSING
        }
        val backgroundLocation = when {
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> if (anyLocation) Availability.AVAILABLE else Availability.PERMISSION_MISSING
            granted(Manifest.permission.ACCESS_BACKGROUND_LOCATION) -> Availability.AVAILABLE
            else -> Availability.PERMISSION_MISSING
        }
        val notifications = if (notificationsEnabled()) Availability.AVAILABLE else Availability.PERMISSION_MISSING
        val overlay = if (Settings.canDrawOverlays(context)) Availability.AVAILABLE else Availability.PERMISSION_MISSING
        val usage = if (usageAccess) Availability.AVAILABLE else Availability.PERMISSION_MISSING

        return CapabilityReportMessage(
            platform = "ANDROID",
            osMajorVersion = Build.VERSION.SDK_INT.toLong(),
            deviceModel = Build.MODEL ?: "unknown",
            radioSignal = radioSignal,
            cqi = cqi,
            physicalChannel = physicalChannel,
            radioAccessTechnology = rat,
            connectivity = Availability.AVAILABLE, // ACCESS_NETWORK_STATE is a normal permission
            throughput = Availability.AVAILABLE, // TrafficStats needs no permission
            foregroundApp = usage,
            callDetection = usage,
            location = if (anyLocation) Availability.AVAILABLE else Availability.PERMISSION_MISSING,
            backgroundLocation = backgroundLocation,
            notifications = notifications,
            surveyOverlay = overlay,
        )
    }

    private fun granted(permission: String): Boolean =
        context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION") // unsafeCheckOpNoThrow is API 29+; minSdk is lower.
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasCarrierPrivileges(): Boolean = try {
        (context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager).hasCarrierPrivileges()
    } catch (e: SecurityException) {
        false
    }

    private fun notificationsEnabled(): Boolean =
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
}
