package io.github.kouotou.qoesense

import io.github.kouotou.qoesense.collector.ForegroundTypes
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class ForegroundTypesTest {
    @Test
    fun `with location, location alone is tried first, never combined with dataSync`() {
        val c = ForegroundTypes.candidates(sdkInt = 36, hasLocation = true)
        assertEquals(listOf(ForegroundTypes.LOCATION, ForegroundTypes.DATA_SYNC), c)
        assertFalse(c.any { it and ForegroundTypes.LOCATION != 0 && it and ForegroundTypes.DATA_SYNC != 0 })
    }

    @Test
    fun `without location, dataSync is the only option`() {
        assertEquals(listOf(ForegroundTypes.DATA_SYNC), ForegroundTypes.candidates(sdkInt = 35, hasLocation = false))
    }

    @Test
    fun `before Android 10 no type is passed`() {
        assertEquals(listOf(0), ForegroundTypes.candidates(sdkInt = 28, hasLocation = true))
    }
}
