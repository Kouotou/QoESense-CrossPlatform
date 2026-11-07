package io.github.kouotou.qoesense.collector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import io.github.kouotou.qoesense.upload.UploadScheduler

/**
 * Port of the reference service/BootReceiver.kt: after a reboot, restart collection only if
 * it was enabled before. The reference also re-armed the upload schedule; WorkManager keeps
 * periodic work across reboots, and scheduling again with KEEP is a no-op.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // MY_PACKAGE_REPLACED: an app update kills the process. Without this, collection would
        // stay off until the next reboot or until the participant opens the app.
        if (intent.action != Intent.ACTION_BOOT_COMPLETED && intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val app = context.applicationContext
        if (CollectorPrefs(app).collectionEnabled) {
            CollectorService.start(app)
            UploadScheduler.schedule(app)
        }
    }
}
