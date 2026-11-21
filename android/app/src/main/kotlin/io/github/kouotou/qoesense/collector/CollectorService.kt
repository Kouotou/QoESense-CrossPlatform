package io.github.kouotou.qoesense.collector

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
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
import io.github.kouotou.qoesense.CollectorEvents
import io.github.kouotou.qoesense.MainActivity
import io.github.kouotou.qoesense.R
import io.github.kouotou.qoesense.TelemetryHostApi
import io.github.kouotou.qoesense.AndroidCapabilityReporter
import io.github.kouotou.qoesense.capture.PermissionUtils
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The native foreground service. Same lifecycle as the reference TelemetryForegroundService:
 * - type location (dataSync only as a fallback, see [ForegroundTypes]);
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
    private var events: CollectorEvents? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!enterForeground()) {
            // Android refused every type (e.g. Android 15+ after the dataSync 6-hour budget, or a
            // background start it doesn't allow). Stop cleanly instead of crashing; the watchdog
            // alarm retries, and opening the app restarts collection.
            stopSelf()
            return START_NOT_STICKY
        }
        isRunning = true
        if (engine == null) startEngine()
        WakeAlarm.schedule(this)
        instance = this
        return START_STICKY
    }

    /**
     * Tries [ForegroundTypes.candidates] in order. On API 34+ the location type throws unless
     * location is granted (and, for a background start, "Allow all the time"); without it,
     * collection continues and the location fields come back PERMISSION_DENIED.
     */
    private fun enterForeground(): Boolean {
        val hasLocation = PermissionUtils.hasForegroundLocation(this)
        for (type in ForegroundTypes.candidates(Build.VERSION.SDK_INT, hasLocation)) {
            try {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, buildNotification(), type)
                Log.i(TAG, "foreground with type $type")
                return true
            } catch (e: Exception) { // SecurityException, ForegroundServiceStartNotAllowedException
                Log.w(TAG, "foreground type $type refused", e)
            }
        }
        return false
    }

    /**
     * Android 15+: a dataSync service reached its 6-hour background budget. It must stop within
     * seconds or the app crashes. Only reached when running as the dataSync fallback.
     */
    override fun onTimeout(startId: Int, fgsType: Int) {
        Log.w(TAG, "foreground service time limit reached (type $fgsType); stopping until the app is opened")
        stopSelf()
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
        events = CollectorEvents(e.dartExecutor.binaryMessenger)
        Log.i(TAG, "collector engine started")
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        scope.cancel()
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
            .setSmallIcon(R.drawable.ic_stat_qoesense)
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

        @Volatile
        private var instance: CollectorService? = null

        /** Forwards a Doze wake-up to the Dart collector (see WakeAlarm). */
        fun wake() {
            val s = instance ?: return
            s.scope.launch {
                try {
                    s.events?.wakeTick()
                } catch (e: Exception) {
                    Log.w(TAG, "wakeTick not delivered", e)
                }
            }
        }

        /** Never throws: a refused background start (Android 12+/15+ limits) is logged, not fatal. */
        fun start(context: Context) {
            try {
                ContextCompat.startForegroundService(context, Intent(context, CollectorService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "collector start refused", e)
            }
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
