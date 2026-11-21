package io.github.kouotou.qoesense.upload

/**
 * Which network an upload run may use (owner decision, 2026-11-21).
 *
 * - Wi-Fi (any unmetered network): always, every 3 hours as before.
 * - Mobile data (any metered network, including a phone hotspot): only once the phone has gone
 *   [MOBILE_DATA_AFTER_MS] (2 days) without a successful upload, so a participant without Wi-Fi
 *   sends about 1-2 MB a month. "Upload now" may use it at once.
 * - Never while roaming, never when the participant turned the switch off, never under
 *   Android's Data Saver.
 *
 * Measured basis (test phone, 2026-11-21): ~450 samples/day x ~32 B gzipped = ~14 KB/day,
 * plus ~35 KB of connection overhead per run.
 */
object UploadNetworkPolicy {
    const val MOBILE_DATA_AFTER_MS = 2L * 24 * 60 * 60 * 1000

    data class Network(val unmetered: Boolean, val roaming: Boolean, val dataSaverOn: Boolean)

    /**
     * [lastUploadMs] is the last run that uploaded rows; before the first one, the 2 days count
     * from consent ([consentMs]). With neither, mobile data waits.
     */
    fun mayUpload(
        network: Network,
        mobileDataAllowed: Boolean,
        userRequested: Boolean,
        lastUploadMs: Long?,
        consentMs: Long?,
        nowMs: Long,
    ): Boolean {
        if (network.roaming) return false
        if (network.unmetered) return true
        if (!mobileDataAllowed || network.dataSaverOn) return false
        if (userRequested) return true
        val since = lastUploadMs ?: consentMs ?: return false
        return nowMs < since || nowMs - since >= MOBILE_DATA_AFTER_MS // a clock set back counts as due
    }
}
