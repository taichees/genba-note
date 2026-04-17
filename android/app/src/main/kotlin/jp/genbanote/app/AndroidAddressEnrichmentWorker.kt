package jp.genbanote.app

import android.content.Context
import android.location.Location
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
        val notificationHelper = WidgetNotificationHelper(applicationContext)
        val locationService = AndroidLocationService(applicationContext)
        repository.updateAddressStatus(workLogId.toInt(), "pending")

        return try {
            val location = when {
                !cachedLatitude.isNaN() && !cachedLongitude.isNaN() ->
                    AndroidLocationService(applicationContext).tryGetRecentCachedLocation()
                        ?: toLocation(cachedLatitude, cachedLongitude)
                else -> tryResolveLocation(locationService)
            }

            if (location == null) {
                if (runAttemptCount < MAX_WORK_ATTEMPTS - 1) {
                    return Result.retry()
                }

                repository.updateAddressStatus(workLogId.toInt(), "failed")
                notificationHelper.showRecordCompleted(withLocation = false)
                return Result.success()
            }

            repository.updateLocation(
                id = workLogId.toInt(),
                latitude = location.latitude,
                longitude = location.longitude,
            )

            val address = AndroidAddressService(applicationContext).getRoughAddress(
                latitude = location.latitude,
                longitude = location.longitude,
            )

            if (address != null) {
                repository.updateRoughAddress(workLogId.toInt(), address)
            } else {
                repository.updateAddressStatus(workLogId.toInt(), "failed")
            }
            notificationHelper.showRecordCompleted(withLocation = true)
            Result.success()
        } catch (_: Exception) {
            repository.updateAddressStatus(workLogId.toInt(), "failed")
            notificationHelper.showRecordCompleted(withLocation = false)
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

        private fun tryResolveLocation(locationService: AndroidLocationService): Location? {
            repeat(INLINE_LOCATION_ATTEMPTS) {
                val freshLocation = locationService.tryGetFreshLocation()
                if (freshLocation != null) {
                    return freshLocation
                }
                Thread.sleep(INLINE_RETRY_INTERVAL_MILLIS)
            }

            val cachedLocation = locationService.tryGetRecentCachedLocation()
            if (cachedLocation != null) {
                return cachedLocation
            }

            return null
        }

        private fun toLocation(latitude: Double, longitude: Double): Location {
            return Location("cached").apply {
                this.latitude = latitude
                this.longitude = longitude
            }
        }

        private const val INLINE_LOCATION_ATTEMPTS = 4
        private const val INLINE_RETRY_INTERVAL_MILLIS = 2_000L
        private const val MAX_WORK_ATTEMPTS = 3
        private const val RETRY_BACKOFF_SECONDS = 10L
    }
}
