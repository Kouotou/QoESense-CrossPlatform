package io.github.kouotou.qoesense.survey

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log

/**
 * Sound and vibration when the rating pop-up appears (owner request, 2026-11-21: with the phone
 * on a table, a silent pop-up was easy to miss). It follows the phone's own settings, like any
 * notification: the default notification sound and a short vibration in normal mode, vibration
 * only in vibrate mode, nothing in silent mode or Do Not Disturb.
 */
object SurveyAlert {
    data class Alert(val sound: Boolean, val vibrate: Boolean)

    private val PATTERN = longArrayOf(0, 300, 150, 300)

    fun decide(ringerMode: Int, doNotDisturb: Boolean): Alert = when {
        doNotDisturb -> Alert(sound = false, vibrate = false)
        ringerMode == AudioManager.RINGER_MODE_NORMAL -> Alert(sound = true, vibrate = true)
        ringerMode == AudioManager.RINGER_MODE_VIBRATE -> Alert(sound = false, vibrate = true)
        else -> Alert(sound = false, vibrate = false)
    }

    fun play(context: Context) {
        val audio = context.getSystemService(AudioManager::class.java)
        val nm = context.getSystemService(NotificationManager::class.java)
        val alert = decide(audio.ringerMode, nm.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL)
        if (alert.sound) {
            try {
                RingtoneManager.getRingtone(context, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))?.apply {
                    audioAttributes = AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                    play()
                }
            } catch (e: Exception) {
                Log.w(TAG, "survey sound failed", e)
            }
        }
        if (alert.vibrate) {
            try {
                val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(VibratorManager::class.java).defaultVibrator
                } else {
                    @Suppress("DEPRECATION")
                    context.getSystemService(Vibrator::class.java)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(PATTERN, -1))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(PATTERN, -1)
                }
            } catch (e: Exception) {
                Log.w(TAG, "survey vibration failed", e)
            }
        }
        Log.i(TAG, "survey alert: sound=${alert.sound} vibrate=${alert.vibrate}")
    }

    private const val TAG = "QoESenseSurvey"
}
