package jp.genbanote.app

import android.content.Context
import android.util.Log

class AndroidQuickRecordService(private val appContext: Context) {
    private val repository = AndroidWorkLogRepository(appContext)
    private val locationService = AndroidLocationService(appContext)

    fun createQuickRecord(): QuickRecordResult {
        return try {
            Log.d(TAG, "Attempting quick record from widget")
            if (!repository.hasPaidPlan() && repository.countWorkLogs() >= FREE_LIMIT) {
                QuickRecordResult.FreeLimitReached
            } else {
                val cachedLocation = locationService.tryGetBestEffortCachedLocation()
                Log.d(
                    TAG,
                    "Widget cached location lat=${cachedLocation?.latitude} lon=${cachedLocation?.longitude}",
                )
                val workLogId = repository.insertQuickRecord(
                    latitude = cachedLocation?.latitude,
                    longitude = cachedLocation?.longitude,
                )
                repository.updateAddressStatus(workLogId, "pending")
                AndroidAddressEnrichmentWorker.enqueue(
                    context = appContext,
                    workLogId = workLogId,
                    latitude = cachedLocation?.latitude,
                    longitude = cachedLocation?.longitude,
                )
                QuickRecordResult.Success(workLogId)
            }
        } catch (error: Exception) {
            Log.e(TAG, "Failed to create widget quick record", error)
            QuickRecordResult.Failure
        }
    }

    companion object {
        private const val TAG = "AndroidQuickRecord"
        private const val FREE_LIMIT = 50
    }
}

sealed interface QuickRecordResult {
    data class Success(val workLogId: Int) : QuickRecordResult
    data object FreeLimitReached : QuickRecordResult
    data object Failure : QuickRecordResult
}
