package jp.genbanote.app

import android.content.Context
import android.location.Location

class AndroidWidgetRecordEnricher(context: Context) {
    private val repository = AndroidWorkLogRepository(context)
    private val locationService = AndroidLocationService(context)
    private val addressService = AndroidAddressService(context)

    fun enrich(
        workLogId: Int,
        latitude: Double?,
        longitude: Double?,
        requireBackgroundPermission: Boolean,
    ): EnrichmentResult {
        repository.updateAddressStatus(workLogId, "pending")

        val location = when {
            latitude != null && longitude != null -> toLocation(latitude, longitude)
            else -> resolveLocation(requireBackgroundPermission)
        } ?: return EnrichmentResult.MissingLocation

        repository.updateLocation(
            id = workLogId,
            latitude = location.latitude,
            longitude = location.longitude,
        )

        val address = addressService.getRoughAddress(
            latitude = location.latitude,
            longitude = location.longitude,
        )

        if (address != null) {
            repository.updateRoughAddress(workLogId, address)
        } else {
            repository.updateAddressStatus(workLogId, "failed")
        }

        return EnrichmentResult.Completed(withLocation = true)
    }

    private fun resolveLocation(requireBackgroundPermission: Boolean): Location? {
        repeat(INLINE_LOCATION_ATTEMPTS) {
            val freshLocation = locationService.tryGetFreshLocation(
                requireBackground = requireBackgroundPermission,
            )
            if (freshLocation != null) {
                return freshLocation
            }

            val cachedLocation = locationService.tryGetBestEffortCachedLocation(
                requireBackground = requireBackgroundPermission,
            )
            if (cachedLocation != null) {
                return cachedLocation
            }

            Thread.sleep(INLINE_RETRY_INTERVAL_MILLIS)
        }

        return null
    }

    private fun toLocation(latitude: Double, longitude: Double): Location {
        return Location("cached").apply {
            this.latitude = latitude
            this.longitude = longitude
        }
    }

    companion object {
        private const val INLINE_LOCATION_ATTEMPTS = 3
        private const val INLINE_RETRY_INTERVAL_MILLIS = 2_000L
    }
}

sealed interface EnrichmentResult {
    data class Completed(val withLocation: Boolean) : EnrichmentResult
    data object MissingLocation : EnrichmentResult
}
