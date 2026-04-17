package jp.genbanote.app

import android.Manifest
import android.os.Build
import android.os.CancellationSignal
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import androidx.core.content.ContextCompat
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AndroidLocationService(private val context: Context) {
    fun tryGetFreshLocation(): Location? {
        if (!hasLocationPermission()) {
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        if (!locationManager.isLocationEnabled) {
            return null
        }

        val currentLocation = tryGetCurrentLocation(locationManager)
        if (currentLocation != null) {
            return currentLocation
        }

        return tryGetRecentLastKnownLocation(locationManager)
    }

    fun tryGetRecentCachedLocation(): Location? {
        if (!hasLocationPermission()) {
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        return tryGetRecentLastKnownLocation(locationManager)
    }

    private fun tryGetCurrentLocation(locationManager: LocationManager): Location? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            return null
        }

        val providers = runCatching { locationManager.getProviders(true) }.getOrNull() ?: return null
        val prioritizedProviders = providers.sortedBy { providerPriority(it) }
        var bestLocation: Location? = null

        for (provider in prioritizedProviders) {
            val location = tryGetCurrentLocationForProvider(locationManager, provider) ?: continue
            if (isBetterLocation(candidate = location, current = bestLocation)) {
                bestLocation = location
            }
        }

        return bestLocation
    }

    private fun tryGetCurrentLocationForProvider(
        locationManager: LocationManager,
        provider: String,
    ): Location? {
        val latch = CountDownLatch(1)
        val executor = Executors.newSingleThreadExecutor()
        val scheduler = Executors.newSingleThreadScheduledExecutor()
        val cancellationSignal = CancellationSignal()
        var location: Location? = null

        try {
            scheduler.schedule(
                {
                    cancellationSignal.cancel()
                    latch.countDown()
                },
                CURRENT_LOCATION_TIMEOUT_MILLIS,
                TimeUnit.MILLISECONDS,
            )

            locationManager.getCurrentLocation(
                provider,
                cancellationSignal,
                executor,
            ) { currentLocation ->
                location = currentLocation
                latch.countDown()
            }

            latch.await(CURRENT_LOCATION_TIMEOUT_MILLIS + 300, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            return null
        } finally {
            scheduler.shutdownNow()
            executor.shutdownNow()
        }

        return location
    }

    private fun tryGetRecentLastKnownLocation(locationManager: LocationManager): Location? {
        val providers = runCatching { locationManager.getProviders(true) }.getOrNull() ?: return null
        val now = System.currentTimeMillis()
        var bestLocation: Location? = null

        for (provider in providers) {
            val location = runCatching {
                locationManager.getLastKnownLocation(provider)
            }.getOrNull() ?: continue

            val ageMillis = now - location.time
            if (ageMillis > LAST_KNOWN_MAX_AGE_MILLIS) {
                continue
            }

            if (isBetterLocation(candidate = location, current = bestLocation)) {
                bestLocation = location
            }
        }

        return bestLocation
    }

    private fun isBetterLocation(candidate: Location, current: Location?): Boolean {
        if (current == null) {
            return true
        }

        if (candidate.time != current.time) {
            return candidate.time > current.time
        }

        return candidate.accuracy < current.accuracy
    }

    private fun providerPriority(provider: String): Int {
        return when (provider) {
            LocationManager.GPS_PROVIDER -> 0
            LocationManager.NETWORK_PROVIDER -> 1
            LocationManager.PASSIVE_PROVIDER -> 2
            else -> 3
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    companion object {
        private const val CURRENT_LOCATION_TIMEOUT_MILLIS = 2_500L
        private const val LAST_KNOWN_MAX_AGE_MILLIS = 10 * 60 * 1_000L
    }
}
