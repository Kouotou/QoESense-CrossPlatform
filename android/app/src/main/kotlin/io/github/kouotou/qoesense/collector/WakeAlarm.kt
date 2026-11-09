package io.github.kouotou.qoesense.collector

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log

/**
 * Decision C (owner, 2026-11-09): bounded gaps while the phone sleeps.
 *
 * In Doze the CPU is suspended, so the collector's timer stops. On the test phone that meant
 * about 1 sample per 45 min, and a 5 h gap overnight. This alarm wakes the phone about every
 * [INTERVAL_MS] with setAndAllowWhileIdle, which is inexact, needs no exact-alarm permission,
 * and which Doze lets through at most about once per 9 min. The receiver:
 * - holds a short partial wake lock (honoured in Doze because the app is exempt from battery
 *   optimisation);
 * - asks the Dart collector to take its overdue sample.
 *
 * While the phone is awake, the Dart side ignores the wake-up, so the 60 s / 15 s cadence is
 * unchanged. Cost: at most [WAKE_LOCK_MS] of CPU per [INTERVAL_MS] while asleep.
 */
object WakeAlarm {
    const val INTERVAL_MS = 10 * 60 * 1000L
    const val WAKE_LOCK_MS = 30_000L // a tick needs ≤ ~16 s (location 15 s, concurrent with radio/RTT)
    private const val REQUEST_CODE = 42

    fun schedule(context: Context) {
        val am = context.getSystemService(AlarmManager::class.java)
        am.setAndAllowWhileIdle(
            AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime() + INTERVAL_MS,
            pendingIntent(context),
        )
    }

    fun cancel(context: Context) {
        context.getSystemService(AlarmManager::class.java).cancel(pendingIntent(context))
    }

    private fun pendingIntent(context: Context) = PendingIntent.getBroadcast(
        context,
        REQUEST_CODE,
        Intent(context, WakeAlarmReceiver::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

class WakeAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        if (!CollectorPrefs(app).collectionEnabled) return
        val pm = app.getSystemService(PowerManager::class.java)
        pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "qoesense:doze-tick").acquire(WakeAlarm.WAKE_LOCK_MS)
        WakeAlarm.schedule(app) // next one first, so a failure below can't break the chain
        if (CollectorService.isRunning) {
            CollectorService.wake()
        } else {
            // Watchdog: the OEM or the system killed the service. Restarting from an alarm can
            // be refused by background-start limits; opening the app restarts it then.
            try {
                CollectorService.start(app)
            } catch (e: Exception) {
                Log.w("QoESenseCollector", "watchdog restart refused", e)
            }
        }
    }
}
