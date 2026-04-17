package jp.genbanote.app

import android.content.Context
import android.location.Geocoder
import java.util.Locale

class AndroidAddressService(context: Context) {
    private val geocoder = Geocoder(context, Locale.JAPAN)

    @Suppress("DEPRECATION")
    fun getRoughAddress(latitude: Double, longitude: Double): String? {
        return try {
            if (!Geocoder.isPresent()) {
                return null
            }

            val placemarks = geocoder.getFromLocation(latitude, longitude, 1)
            val placemark = placemarks?.firstOrNull() ?: return null

            val city = cleanPart(placemark.locality)
                ?: cleanPart(placemark.subAdminArea)
                ?: cleanPart(placemark.adminArea)
                ?: ""
            val town = cleanPart(placemark.subLocality)
                ?: cleanPart(placemark.thoroughfare)
                ?: ""

            val result = "$city$town"
            if (result.isBlank()) {
                return null
            }

            "${result}付近"
        } catch (_: Exception) {
            null
        }
    }

    private fun cleanPart(value: String?): String? {
        val trimmed = value?.trim()
        if (trimmed.isNullOrEmpty()) {
            return null
        }
        return trimmed
    }
}
