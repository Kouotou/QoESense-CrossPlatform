package io.github.kouotou.qoesense

import android.media.AudioManager
import io.github.kouotou.qoesense.survey.SurveyAlert
import io.github.kouotou.qoesense.survey.SurveyAlert.Alert
import org.junit.Assert.assertEquals
import org.junit.Test

class SurveyAlertTest {
    @Test
    fun `normal ring mode plays the sound and vibrates`() {
        assertEquals(Alert(sound = true, vibrate = true), SurveyAlert.decide(AudioManager.RINGER_MODE_NORMAL, doNotDisturb = false))
    }

    @Test
    fun `vibrate mode only vibrates`() {
        assertEquals(Alert(sound = false, vibrate = true), SurveyAlert.decide(AudioManager.RINGER_MODE_VIBRATE, doNotDisturb = false))
    }

    @Test
    fun `silent mode and Do Not Disturb stay silent`() {
        assertEquals(Alert(sound = false, vibrate = false), SurveyAlert.decide(AudioManager.RINGER_MODE_SILENT, doNotDisturb = false))
        assertEquals(Alert(sound = false, vibrate = false), SurveyAlert.decide(AudioManager.RINGER_MODE_NORMAL, doNotDisturb = true))
    }
}
