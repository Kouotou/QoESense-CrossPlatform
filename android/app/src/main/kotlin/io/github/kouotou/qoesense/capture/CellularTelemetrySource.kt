package io.github.kouotou.qoesense.capture

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import android.telephony.CellInfo
import android.telephony.CellInfoLte
import android.telephony.PhysicalChannelConfig
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi
import io.github.kouotou.qoesense.MeasurementStatus
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicReference

/**
 * Port of the reference telemetry/CellularTelemetrySource.kt. The capture logic is unchanged:
 * - the serving LTE cell (registered, else the first LTE cell) from getAllCellInfo();
 * - the same sentinel handling and the same cell-identity hash;
 * - the same PhysicalChannelConfig listener, which throws SecurityException without carrier
 *   privileges.
 *
 * Additions for contract v2:
 * - a status per group;
 * - the reading's own age from CellInfo's timestamp;
 * - networkType read independently of whether an LTE cell is visible (in the reference it
 *   was null whenever no LTE cell was visible).
 */
class CellularTelemetrySource(private val context: Context) {

    data class Reading(
        val rsrp: Int?,
        val rsrq: Int?,
        val rssnr: Int?,
        val timingAdvance: Int?,
        val cellIdentityHash: String?,
        val trackingAreaCode: Int?,
        val signalStrengthLevel: Int?,
        val radioStatus: MeasurementStatus,
        val cellInfoAgeMs: Long?,
        val cqi: Int?,
        val cqiStatus: MeasurementStatus,
        val cellBandwidthKhz: Int?,
        val downlinkChannelNumber: Int?,
        val uplinkChannelNumber: Int?,
        val physicalChannelStatus: MeasurementStatus,
        val networkType: String?,
        val networkTypeStatus: MeasurementStatus,
    )

    private val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
    private val hasTelephony = context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY)
    private val latestPhysicalChannelConfigs = AtomicReference<List<PhysicalChannelConfig>>(emptyList())
    private var telephonyCallback: TelephonyCallback? = null
    private var physicalChannelRestricted = false
    private var started = false

    @SuppressLint("MissingPermission")
    fun start() {
        if (started || !hasTelephony || !PermissionUtils.hasPhoneState(context)) return
        started = true
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val callback = object : TelephonyCallback(), TelephonyCallback.PhysicalChannelConfigListener {
                override fun onPhysicalChannelConfigChanged(configs: MutableList<PhysicalChannelConfig>) {
                    latestPhysicalChannelConfigs.set(configs.toList())
                }
            }
            try {
                telephonyManager.registerTelephonyCallback(context.mainExecutor, callback)
                telephonyCallback = callback
            } catch (e: SecurityException) {
                // Needs carrier privileges - essentially every participant phone lacks them.
                physicalChannelRestricted = true
            }
        }
    }

    fun stop() {
        if (!started) return
        started = false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let { telephonyManager.unregisterTelephonyCallback(it) }
        }
        telephonyCallback = null
    }

    @SuppressLint("MissingPermission") // guarded by PermissionUtils checks
    fun readCurrent(staleAfterMs: Long): Reading {
        if (!hasTelephony) return unsupported()
        start() // idempotent; picks up a permission granted after the service started

        val phoneState = PermissionUtils.hasPhoneState(context)
        val networkType = if (phoneState) networkTypeName() else null
        val networkTypeStatus = if (phoneState) MeasurementStatus.OK else MeasurementStatus.PERMISSION_DENIED
        val physStatusIfNoValue = physicalChannelStatusWithoutValue()

        if (!phoneState || !PermissionUtils.hasForegroundLocation(context)) {
            val denied = MeasurementStatus.PERMISSION_DENIED
            return empty(denied, cqiStatus(denied), physStatusIfNoValue, networkType, networkTypeStatus)
        }

        val lteCells = telephonyManager.allCellInfo.orEmpty().filterIsInstance<CellInfoLte>()
        val cell = lteCells.firstOrNull { it.isRegistered } ?: lteCells.firstOrNull()
        if (cell == null) {
            val unavailable = MeasurementStatus.UNAVAILABLE
            return empty(unavailable, cqiStatus(unavailable), physStatusIfNoValue, networkType, networkTypeStatus)
        }

        val signalStrength = cell.cellSignalStrength
        val identity = cell.cellIdentity
        val ageMs = cellAgeMs(cell)
        val radioStatus = if (ageMs != null && ageMs > staleAfterMs) MeasurementStatus.STALE else MeasurementStatus.OK

        val cqi = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) signalStrength.cqi.takeIfAvailable() else null
        val physChan = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) readPhysicalChannelFields() else null

        return Reading(
            rsrp = signalStrength.rsrp.takeIfAvailable(),
            rsrq = signalStrength.rsrq.takeIfAvailable(),
            rssnr = signalStrength.rssnr.takeIfAvailable(),
            timingAdvance = signalStrength.timingAdvance.takeIfAvailable(),
            cellIdentityHash = hashCellIdentity(identity.ci, identity.tac),
            trackingAreaCode = identity.tac.takeIfAvailable(),
            signalStrengthLevel = signalStrength.level,
            radioStatus = radioStatus,
            cellInfoAgeMs = ageMs,
            cqi = cqi,
            // Freshness is carried by radioStatus/cellInfoAgeMs. STALE is defined only for
            // radio and location (DATA_CONTRACT §5).
            cqiStatus = when {
                Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> MeasurementStatus.NOT_SUPPORTED
                cqi != null -> MeasurementStatus.OK
                else -> MeasurementStatus.UNAVAILABLE
            },
            cellBandwidthKhz = physChan?.cellBandwidthKhz,
            downlinkChannelNumber = physChan?.downlinkChannelNumber,
            uplinkChannelNumber = physChan?.uplinkChannelNumber,
            physicalChannelStatus = if (physChan?.hasAny == true) MeasurementStatus.OK else physStatusIfNoValue,
            networkType = networkType,
            networkTypeStatus = networkTypeStatus,
        )
    }

    private fun cqiStatus(radio: MeasurementStatus) =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) MeasurementStatus.NOT_SUPPORTED else radio

    private fun physicalChannelStatusWithoutValue(): MeasurementStatus = when {
        Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> MeasurementStatus.NOT_SUPPORTED
        physicalChannelRestricted -> MeasurementStatus.RESTRICTED
        !PermissionUtils.hasPhoneState(context) -> MeasurementStatus.PERMISSION_DENIED
        else -> MeasurementStatus.UNAVAILABLE
    }

    /** Age from the CellInfo's own timestamp. Both clocks are elapsedRealtime-based. */
    private fun cellAgeMs(cell: CellInfo): Long? {
        val stampMs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            cell.timestampMillis
        } else {
            @Suppress("DEPRECATION")
            cell.timeStamp / 1_000_000L
        }
        if (stampMs <= 0) return null
        return (SystemClock.elapsedRealtime() - stampMs).coerceAtLeast(0)
    }

    private fun unsupported(): Reading {
        val ns = MeasurementStatus.NOT_SUPPORTED
        return empty(ns, ns, ns, null, ns)
    }

    private fun empty(
        radio: MeasurementStatus,
        cqi: MeasurementStatus,
        phys: MeasurementStatus,
        networkType: String?,
        networkTypeStatus: MeasurementStatus,
    ) = Reading(
        rsrp = null, rsrq = null, rssnr = null, timingAdvance = null, cellIdentityHash = null,
        trackingAreaCode = null, signalStrengthLevel = null, radioStatus = radio, cellInfoAgeMs = null,
        cqi = null, cqiStatus = cqi, cellBandwidthKhz = null, downlinkChannelNumber = null,
        uplinkChannelNumber = null, physicalChannelStatus = phys, networkType = networkType,
        networkTypeStatus = networkTypeStatus,
    )

    private data class PhysChanFields(val cellBandwidthKhz: Int?, val downlinkChannelNumber: Int?, val uplinkChannelNumber: Int?) {
        val hasAny get() = cellBandwidthKhz != null || downlinkChannelNumber != null || uplinkChannelNumber != null
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun readPhysicalChannelFields(): PhysChanFields? {
        val config = latestPhysicalChannelConfigs.get().firstOrNull() ?: return null
        return PhysChanFields(
            cellBandwidthKhz = config.cellBandwidthDownlinkKhz.takeIfAvailable(),
            downlinkChannelNumber = config.downlinkChannelNumber.takeIfAvailable(),
            uplinkChannelNumber = config.uplinkChannelNumber.takeIfAvailable(),
        )
    }

    @SuppressLint("MissingPermission")
    private fun networkTypeName(): String {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            telephonyManager.dataNetworkType
        } else {
            @Suppress("DEPRECATION")
            telephonyManager.networkType
        }
        return when (type) {
            TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
            TelephonyManager.NETWORK_TYPE_NR -> "NR"
            TelephonyManager.NETWORK_TYPE_UNKNOWN -> "UNKNOWN"
            else -> "OTHER"
        }
    }

    private fun Int.takeIfAvailable(): Int? =
        if (this == CellInfo.UNAVAILABLE || this == Int.MAX_VALUE) null else this

    private fun hashCellIdentity(ci: Int, tac: Int): String? {
        if (ci == Int.MAX_VALUE || ci == CellInfo.UNAVAILABLE) return null
        val digest = MessageDigest.getInstance("SHA-256").digest("$ci:$tac".toByteArray())
        return digest.joinToString("") { "%02x".format(it) }.take(16)
    }
}
