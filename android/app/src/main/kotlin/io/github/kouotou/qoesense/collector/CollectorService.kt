package io.github.kouotou.qoesense.collector

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.github.kouotou.qoesense.AndroidCollectorApi
import io.github.kouotou.qoesense.MainActivity
import io.github.kouotou.qoesense.R
import io.github.kouotou.qoesense.TelemetryHostApi
import io.github.kouotou.qoesense.AndroidCapabilityReporter
import io.github.kouotou.qoesense.capture.PermissionUtils

/**
 * The native foreground service. Same lifecycle as the reference TelemetryForegroundService:
 * - type dataSync|location;
 * - a low-priority, silent, ongoing notification;
 * - START_STICKY, so the system restarts it after a kill.
 *
 * Instead of a Kotlin coroutine loop, it hosts a **headless Flutter engine** running the
 * Dart entrypoint `collectorMain`. That engine runs the shared rules (SamplingPolicy,
 * SurveyTriggerPolicy, the anomaly detector), the drift buffer and the MOS pipeline, and
 * calls back here once per tick for a whole native capture. The service owns the process
 * lifetime; Dart owns the decisions.
 */
class CollectorService : Service() {
    private var engine: FlutterEngine? = null
    private var host: AndroidCollectorHost? = null

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), foregroundTypes())
        isRunning = true
        if (engine == null) startEngine()
        return START_STICKY
    }

    /**
     * On API 34+, the location type may only be requested while location is granted,
     * otherwise startForeground throws. Without it, collection continues and the location
     * fields come back PERMISSION_DENIED.
     */
    private fun foregroundTypes(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return 0
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        if (PermissionUtils.hasForegroundLocation(this)) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
        return types
    }

    private fun startEngine() {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, null)
        val e = FlutterEngine(applicationContext) // registers plugins (drift, Firebase, ...)
        val h = AndroidCollectorHost(applicationContext)
        AndroidCollectorApi.setUp(e.dartExecutor.binaryMessenger, h)
        TelemetryHostApi.setUp(e.dartExecutor.binaryMessenger, AndroidCapabilityReporter(applicationContext))
        e.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "collectorMain"),
        )
        engine = e
        host = h
        Log.i(TAG, "collector engine started")
    }

    override fun onDestroy() {
        isRunning = false
        host?.stop()
        engine?.destroy()
        engine = null
        host = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun buildNotification(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.notif_collection_title))
            .setContentText(getString(R.string.notif_collection_text))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
    }

    companion object {
        private const val TAG = "QoESenseCollector"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "telemetry_collection"

        @Volatile
        var isRunning = false
            private set

        fun start(context: Context) {
            ContextCompat.startForegroundService(context, Intent(context, CollectorService::class.java))
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CollectorService::class.java))
        }

        private fun createChannel(context: Context) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notif_collection_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.notif_collection_channel_desc)
                setShowBadge(false)
            }
            context.getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }
}
