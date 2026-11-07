package io.github.kouotou.qoesense.upload

import android.content.Context
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
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.github.kouotou.qoesense.AndroidCollectorApi
import io.github.kouotou.qoesense.collector.AndroidCollectorHost
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Port of the reference service/upload/UploadScheduler.kt, with the same constraints and the
 * same cadence: hourly, unmetered network (Wi-Fi), battery not low, exponential backoff, and
 * unique work with KEEP.
 */
object UploadScheduler {
    private const val WORK_NAME = "telemetry_upload"
    private const val ONE_OFF_NAME = "telemetry_upload_now"

    private val constraints = Constraints.Builder()
        .setRequiredNetworkType(NetworkType.UNMETERED)
        .setRequiresBatteryNotLow(true)
        .build()

    fun schedule(context: Context) {
        val request = PeriodicWorkRequestBuilder<UploadWorker>(1, TimeUnit.HOURS)
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, WorkRequest.MIN_BACKOFF_MILLIS, TimeUnit.MILLISECONDS)
            .build()
        WorkManager.getInstance(context).enqueueUniquePeriodicWork(WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request)
    }

    fun runOnce(context: Context) {
        val request = OneTimeWorkRequestBuilder<UploadWorker>().setConstraints(constraints).build()
        WorkManager.getInstance(context).enqueueUniqueWork(ONE_OFF_NAME, ExistingWorkPolicy.KEEP, request)
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

    private companion object {
        const val TAG = "QoESenseUploadWorker"
    }
}
