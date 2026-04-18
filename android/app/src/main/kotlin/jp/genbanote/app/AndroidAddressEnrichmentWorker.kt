package jp.genbanote.app

import android.content.Context
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters

class AndroidAddressEnrichmentWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {
    override fun doWork(): Result {
        val workLogId = inputData.getLong(KEY_WORK_LOG_ID, -1L)
        val cachedLatitude = inputData.getDouble(KEY_LATITUDE, Double.NaN)
        val cachedLongitude = inputData.getDouble(KEY_LONGITUDE, Double.NaN)

        if (workLogId <= 0L) {
            return Result.failure()
        }

        val repository = AndroidWorkLogRepository(applicationContext)
        val enricher = AndroidWidgetRecordEnricher(applicationContext)

        return try {
            val result = enricher.enrich(
                workLogId = workLogId.toInt(),
                latitude = cachedLatitude.takeUnless { it.isNaN() },
                longitude = cachedLongitude.takeUnless { it.isNaN() },
                requireBackgroundPermission = true,
            )

            if (result is EnrichmentResult.MissingLocation) {
                if (runAttemptCount < MAX_WORK_ATTEMPTS - 1) {
                    return Result.retry()
                }

                repository.updateAddressStatus(workLogId.toInt(), "failed")
                return Result.success()
            }
            Result.success()
        } catch (_: Exception) {
            repository.updateAddressStatus(workLogId.toInt(), "failed")
            Result.failure()
        }
    }

    companion object {
        private const val KEY_WORK_LOG_ID = "work_log_id"
        private const val KEY_LATITUDE = "latitude"
        private const val KEY_LONGITUDE = "longitude"

        fun enqueue(
            context: Context,
            workLogId: Int,
            latitude: Double?,
            longitude: Double?,
        ) {
            val request = OneTimeWorkRequestBuilder<AndroidAddressEnrichmentWorker>()
                .setBackoffCriteria(
                    androidx.work.BackoffPolicy.LINEAR,
                    java.time.Duration.ofSeconds(RETRY_BACKOFF_SECONDS),
                )
                .setInputData(
                    Data.Builder()
                        .putLong(KEY_WORK_LOG_ID, workLogId.toLong())
                        .putDouble(KEY_LATITUDE, latitude ?: Double.NaN)
                        .putDouble(KEY_LONGITUDE, longitude ?: Double.NaN)
                        .build(),
                )
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                "address-enrichment-$workLogId",
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }

        private const val MAX_WORK_ATTEMPTS = 4
        private const val RETRY_BACKOFF_SECONDS = 15L
    }
}
