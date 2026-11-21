package io.github.kouotou.qoesense.collector

import android.content.pm.ServiceInfo
import android.os.Build

/**
 * Which foreground-service type(s) the collector asks for, in order of preference.
 *
 * Android 15+ (targetSdk >= 35) limits `dataSync` foreground services to 6 hours in the
 * background per 24 h, and forbids starting them from BOOT_COMPLETED. `location` has neither
 * limit, so whenever location is granted the service runs as `location` ONLY: combining it with
 * `dataSync` would put the whole service under the 6-hour limit. `dataSync` stays as the
 * fallback when location is missing or Android refuses a background start with the location
 * type (Android 14+ needs "Allow all the time" for that); [CollectorService.onTimeout] then
 * stops the service cleanly and opening the app restarts it.
 */
object ForegroundTypes {
    const val LOCATION = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
    const val DATA_SYNC = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC

    fun candidates(sdkInt: Int, hasLocation: Boolean): List<Int> = when {
        sdkInt < Build.VERSION_CODES.Q -> listOf(0) // types don't exist before API 29
        hasLocation -> listOf(LOCATION, DATA_SYNC)
        else -> listOf(DATA_SYNC)
    }
}
