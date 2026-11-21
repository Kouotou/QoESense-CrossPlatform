package io.github.kouotou.qoesense

import io.github.kouotou.qoesense.upload.UploadNetworkPolicy
import io.github.kouotou.qoesense.upload.UploadNetworkPolicy.Network
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UploadNetworkPolicyTest {
    private val hour = 60L * 60 * 1000
    private val now = 1_800_000_000_000L
    private val wifi = Network(unmetered = true, roaming = false, dataSaverOn = false)
    private val mobile = Network(unmetered = false, roaming = false, dataSaverOn = false)

    private fun may(
        network: Network = mobile,
        allowed: Boolean = true,
        requested: Boolean = false,
        last: Long? = now - 49 * hour,
        consent: Long? = null,
    ) = UploadNetworkPolicy.mayUpload(network, allowed, requested, last, consent, now)

    @Test
    fun `Wi-Fi always uploads, even with the switch off`() {
        assertTrue(may(network = wifi, allowed = false, last = now - hour))
    }

    @Test
    fun `mobile data waits for 2 days without an upload`() {
        assertFalse(may(last = now - 47 * hour))
        assertTrue(may(last = now - 48 * hour))
    }

    @Test
    fun `before the first upload the 2 days count from consent`() {
        assertFalse(may(last = null, consent = now - 24 * hour))
        assertTrue(may(last = null, consent = now - 48 * hour))
        assertFalse(may(last = null, consent = null))
    }

    @Test
    fun `never while roaming, not even on request or on Wi-Fi`() {
        assertFalse(may(network = mobile.copy(roaming = true), requested = true))
        assertFalse(may(network = wifi.copy(roaming = true)))
    }

    @Test
    fun `the participant's switch and Data Saver block mobile data`() {
        assertFalse(may(allowed = false))
        assertFalse(may(allowed = false, requested = true))
        assertFalse(may(network = mobile.copy(dataSaverOn = true)))
    }

    @Test
    fun `Upload now may use mobile data at once`() {
        assertTrue(may(requested = true, last = now - hour))
    }

    @Test
    fun `a clock set back before the last upload counts as due`() {
        assertTrue(may(last = now + hour))
    }
}
