package io.github.kouotou.qoesense.upload

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import io.github.kouotou.qoesense.MainActivity
import io.github.kouotou.qoesense.R

/**
 * The "no upload for 3 days" notification (report alignment, 2026-11-14). When to show it is
 * decided in Dart (UploadReminderPolicy), which also passes the localized texts. A tap opens
 * the app's status screen, where "Upload now" is.
 */
object UploadReminderNotifier {
    private const val CHANNEL_ID = "upload_reminder"
    private const val NOTIFICATION_ID = 3003

    fun show(context: Context, title: String, body: String) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notif_reminder_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = context.getString(R.string.notif_reminder_channel_desc) },
        )
        val open = PendingIntent.getActivity(
            context,
            NOTIFICATION_ID,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setSmallIcon(R.drawable.ic_stat_qoesense)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        // Without the notification permission (Android 13+) this posts nothing, by design.
        nm.notify(NOTIFICATION_ID, n)
    }
}
