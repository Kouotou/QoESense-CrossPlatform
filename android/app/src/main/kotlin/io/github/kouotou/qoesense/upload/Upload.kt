package io.github.kouotou.qoesense.upload

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkRequest
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.github.kouotou.qoesense.AndroidCollectorApi
import io.github.kouotou.qoesense.collector.AndroidCollectorHost
import io.github.kouotou.qoesense.collector.CollectorPrefs
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Port of the reference service/upload/UploadScheduler.kt: battery not low, exponential
 * backoff, unique periodic work, every 3 h instead of hourly (see schedule()).
 *
 * Network (2026-11-21): the reference ran on unmetered networks only. The job now runs on any
 * non-roaming network, and the worker applies [UploadNetworkPolicy]: Wi-Fi always, mobile data
 * only after 2 days without an upload (or on "Upload now"), if the participant allows it.
 */
object UploadScheduler {
    private const val WORK_NAME = "telemetry_upload"
    private const val ONE_OFF_NAME = "telemetry_upload_now"
    const val UPLOAD_PERIOD_HOURS = 3L

    private val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.NOT_ROAMING)
        .setRequiresBatteryNotLow(true)
        .build()

    /**
     * Every 3 hours (free-tier scale decision, 2026-11-14): fewer, larger Firestore batch
     * documents per participant per day. UPDATE, not KEEP, so phones that already have the
     * old hourly job switch to the new period on the next schedule() (app update or start),
     * without losing their place in the schedule.
     */
    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<UploadWorker>(UPLOAD_PERIOD_HOURS, TimeUnit.HOURS)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.UPDATE, request)
    }

    /**
     * "Upload now": REPLACE, not KEEP. With KEEP, a one-off left waiting in WorkManager's retry
     * backoff (e.g. after earlier failed attempts) silently swallowed every later tap. That was
     * found on the test phone on 2026-11-14.
     */
    fun runOnce(context: Context) {
        val request = OneTimeWorkRequestBuilder<UploadWorker>()
            .setConstraints(constraints)
            .setInputData(workDataOf(UploadWorker.KEY_USER_REQUESTED to true))
            .build()
        WorkManager.getInstance(context).enqueueUniqueWork(ONE_OFF_NAME, ExistingWorkPolicy.REPLACE, request)
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
    }
}

/**
 * Replaces the reference TelemetryUploadWorker's body with the shared Dart UploadDrain, so
 * Android and iOS have ONE upload pipeline. WorkManager still owns when it runs and the
 * retry/backoff. The worker starts a headless engine at `uploadMain`, which does:
 * drain (20 × 2000 rows, delete only confirmed batches) → retention (45 days) → the MOS
 * queue. Then it reports back through uploadRunFinished.
 */
class UploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        // One drain at a time per process. The hourly job and an "Upload now" one-off ran
        // concurrently on the test phone (2026-11-14). Two drains reading the same oldest rows
        // could upload them twice (the exporter dedups, but it wastes the free quota).
        if (!RUNNING.compareAndSet(false, true)) {
            Log.i(TAG, "another upload run is in progress - deferring to it")
            return Result.success()
        }
        try {
            if (!networkAllowed()) {
                Log.i(TAG, "on mobile data and not due yet (or not allowed) - skipping this run")
                return Result.success()
            }
            return drainOnce()
        } finally {
            RUNNING.set(false)
        }
    }

    private suspend fun drainOnce(): Result {
        val done = CompletableDeferred<Boolean>()
        val engine = withContext(Dispatchers.Main) {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, null)
            FlutterEngine(applicationContext).also { e ->
                AndroidCollectorApi.setUp(
                    e.dartExecutor.binaryMessenger,
                    AndroidCollectorHost(applicationContext) { success, _ -> done.complete(success) },
                )
                e.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "uploadMain"))
            }
        }
        return try {
            // WorkManager stops a worker after 10 minutes; leave headroom.
            when (withTimeoutOrNull(TimeUnit.MINUTES.toMillis(9)) { done.await() }) {
                true -> Result.success()
                else -> Result.retry() // false = retry requested by Dart; null = timed out
            }
        } catch (e: Exception) {
            Log.e(TAG, "upload run failed", e)
            Result.retry()
        } finally {
            withContext(Dispatchers.Main) { engine.destroy() }
        }
    }

    private fun networkAllowed(): Boolean {
        val prefs = CollectorPrefs(applicationContext)
        return UploadNetworkPolicy.mayUpload(
            network = currentNetwork(applicationContext) ?: return false,
            mobileDataAllowed = prefs.mobileDataUploadsAllowed,
            userRequested = inputData.getBoolean(KEY_USER_REQUESTED, false),
            lastUploadMs = prefs.lastUploadMs,
            consentMs = prefs.consentMs,
            nowMs = System.currentTimeMillis(),
        )
    }

    companion object {
        const val KEY_USER_REQUESTED = "user_requested"
        private const val TAG = "QoESenseUploadWorker"
        private val RUNNING = java.util.concurrent.atomic.AtomicBoolean(false)

        /** The active network as the policy sees it; null when there is none. */
        fun currentNetwork(context: Context): UploadNetworkPolicy.Network? {
            val cm = context.getSystemService(ConnectivityManager::class.java)
            val caps = cm.getNetworkCapabilities(cm.activeNetwork ?: return null) ?: return null
            val unmetered = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                    caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_TEMPORARILY_NOT_METERED))
            val roaming = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_ROAMING)
            } else {
                @Suppress("DEPRECATION")
                cm.activeNetworkInfo?.isRoaming == true
            }
            val dataSaver = cm.restrictBackgroundStatus == ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED
            return UploadNetworkPolicy.Network(unmetered = unmetered, roaming = roaming, dataSaverOn = dataSaver)
        }
    }
}
