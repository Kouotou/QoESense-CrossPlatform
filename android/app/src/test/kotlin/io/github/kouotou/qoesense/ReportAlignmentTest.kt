package io.github.kouotou.qoesense

import io.github.kouotou.qoesense.capture.CellChangeCounter
import io.github.kouotou.qoesense.capture.MonitoredApps
import io.github.kouotou.qoesense.collector.AutoStart
import io.github.kouotou.qoesense.collector.AutoStart.Brand
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CellChangeCounterTest {
    @Test
    fun firstSampleHasNoBaseline() {
        val c = CellChangeCounter()
        c.observe("LTE:1")
        assertNull(c.takeForSample())
    }

    @Test
    fun countsEveryServingCellChangeBetweenSamples() {
        val c = CellChangeCounter()
        c.observe("LTE:1")
        c.takeForSample()
        c.observe("LTE:1") // the same cell again: no change
        assertEquals(0, c.takeForSample())
        c.observe("LTE:2")
        c.observe("LTE:1") // ping-pong counts twice
        c.observe("LTE:1")
        assertEquals(2, c.takeForSample())
        assertEquals(0, c.takeForSample())
    }

    @Test
    fun noServiceIsNotAChange() {
        val c = CellChangeCounter()
        c.observe("LTE:1")
        c.takeForSample()
        c.observe(null)
        c.observe("LTE:1")
        assertEquals(0, c.takeForSample())
    }

    @Test
    fun anUnavailableCellIdIsNotAChange() {
        // Seen on the test phone: the same serving cell, once with its cell ID, once without.
        val withId = CellChangeCounter.cellKey("LTE", 216, 1849, 114946)
        val withoutId = CellChangeCounter.cellKey("LTE", 216, 1849, Int.MAX_VALUE.toLong())
        assertEquals(withId, withoutId)
        // A neighbouring sector of the same site is a real change.
        assertTrue(withId != CellChangeCounter.cellKey("LTE", 22, 1849, 114945))
        assertNull(CellChangeCounter.cellKey("LTE", Int.MAX_VALUE, Int.MAX_VALUE, Int.MAX_VALUE.toLong()))
        assertEquals("LTE:id=7:ch=?", CellChangeCounter.cellKey("LTE", Int.MAX_VALUE, Int.MAX_VALUE, 7))
    }

    @Test
    fun dualSimOrderDoesNotFakeAChange() {
        val a = CellChangeCounter.servingSetKey(listOf("LTE:pci=216:ch=1849", "LTE:pci=22:ch=1849"))
        val b = CellChangeCounter.servingSetKey(listOf("LTE:pci=22:ch=1849", "LTE:pci=216:ch=1849", null))
        assertEquals(a, b)
        assertEquals("LTE:pci=216:ch=1849", CellChangeCounter.servingSetKey(listOf("LTE:pci=216:ch=1849", "LTE:pci=216:ch=1849")))
        assertNull(CellChangeCounter.servingSetKey(listOf(null)))
        assertNull(CellChangeCounter.servingSetKey(emptyList()))
    }

    @Test
    fun resetDropsTheBaseline() {
        val c = CellChangeCounter()
        c.observe("LTE:1")
        c.takeForSample()
        c.observe("LTE:2")
        c.reset()
        c.observe("LTE:3")
        assertNull(c.takeForSample())
        c.observe("LTE:4")
        assertEquals(1, c.takeForSample())
    }
}

class AutoStartTest {
    @Test
    fun mapsManufacturersToFamilies() {
        assertEquals(Brand.TRANSSION, AutoStart.brandOf("INFINIX MOBILITY LIMITED", "Infinix"))
        assertEquals(Brand.TRANSSION, AutoStart.brandOf("TECNO MOBILE LIMITED", "TECNO"))
        assertEquals(Brand.TRANSSION, AutoStart.brandOf("ITEL MOBILE LIMITED", "itel"))
        assertEquals(Brand.XIAOMI, AutoStart.brandOf("Xiaomi", "Redmi"))
        assertEquals(Brand.OPPO, AutoStart.brandOf("realme", "realme"))
        assertEquals(Brand.VIVO, AutoStart.brandOf("vivo", "vivo"))
        assertEquals(Brand.HUAWEI, AutoStart.brandOf("HUAWEI", "HONOR"))
        assertEquals(Brand.SAMSUNG, AutoStart.brandOf("samsung", "samsung"))
        assertEquals(Brand.OTHER, AutoStart.brandOf("Google", "google"))
        assertEquals(Brand.OTHER, AutoStart.brandOf(null, null))
    }

    @Test
    fun everyFamilyButOtherHasACandidateScreen() {
        for (b in Brand.values()) {
            assertEquals(b != Brand.OTHER, AutoStart.candidates(b).isNotEmpty())
        }
    }
}

class MonitoredAppsTest {
    @Test
    fun liteAppsAndMessengerAreSocialMedia() {
        for (p in listOf(
            "com.facebook.lite", "com.facebook.orca", "com.instagram.lite",
            "com.zhiliaoapp.musically.go", "com.ss.android.ugc.trill.go",
            "com.whatsapp", "com.whatsapp.w4b", "com.facebook.katana", "com.instagram.android",
        )) {
            assertTrue(p, p in MonitoredApps.SOCIAL_MEDIA_PACKAGES)
        }
    }

    @Test
    fun messengerAndWhatsAppCallsUseTheInCallCadence() {
        assertEquals(setOf("com.whatsapp", "com.whatsapp.w4b", "com.facebook.orca"), MonitoredApps.CALL_CAPABLE_PACKAGES)
    }
}
