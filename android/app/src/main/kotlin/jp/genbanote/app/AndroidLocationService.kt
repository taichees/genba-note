package jp.genbanote.app

import android.Manifest
import android.os.CancellationSignal
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AndroidLocationService(private val context: Context) {
    fun tryGetFreshLocation(requireBackground: Boolean = true): Location? {
        if (!hasLocationPermission(requireBackground = requireBackground)) {
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        if (!locationManager.isLocationEnabled) {
            return null
        }

        val currentLocation = tryGetFusedCurrentLocation() ?: tryGetCurrentLocation(locationManager)
        if (currentLocation != null) {
            Log.d(TAG, "Resolved fresh widget location from active provider")
            return currentLocation
        }

        return tryGetBestEffortCachedLocation(requireBackground = requireBackground)
    }

    fun tryGetRecentCachedLocation(requireBackground: Boolean = true): Location? {
        if (!hasLocationPermission(requireBackground = requireBackground)) {
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        return tryGetRecentLastKnownLocation(locationManager)
    }

    fun tryGetBestEffortCachedLocation(requireBackground: Boolean = true): Location? {
        if (!hasLocationPermission(requireBackground = requireBackground)) {
            return null
        }

        val locationManager =
            context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null

        val fusedLocation = tryGetFusedLastLocation()
        if (fusedLocation != null) {
            Log.d(TAG, "Resolved widget location from fused cache")
            return fusedLocation
        }

        return tryGetRecentLastKnownLocation(locationManager)
    }

    private fun tryGetFusedCurrentLocation(): Location? {
        val latch = CountDownLatch(1)
        val cancellationTokenSource = CancellationTokenSource()
        var location: Location? = null

        try {
            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
            fusedLocationClient.getCurrentLocation(
                Priority.PRIORITY_HIGH_ACCURACY,
                cancellationTokenSource.token,
            ).addOnSuccessListener { currentLocation ->
                location = currentLocation
                latch.countDown()
            }.addOnFailureListener {
                latch.countDown()
            }

            latch.await(CURRENT_LOCATION_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            return null
        } finally {
            cancellationTokenSource.cancel()
        }

        return location
    }

    private fun tryGetFusedLastLocation(): Location? {
        val latch = CountDownLatch(1)
        var location: Location? = null

        try {
            val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)
            fusedLocationClient.lastLocation
                .addOnSuccessListener { lastLocation ->
                    location = lastLocation
                    latch.countDown()
                }
                .addOnFailureListener {
                    latch.countDown()
                }

            latch.await(LAST_LOCATION_TIMEOUT_MILLIS, TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            return null
        }

        val lastLocation = location ?: return null
        val ageMillis = System.currentTimeMillis() - lastLocation.time
        return if (ageMillis <= LAST_KNOWN_MAX_AGE_MILLIS) {
            lastLocation
        } else {
            null
        }
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

    private fun hasLocationPermission(requireBackground: Boolean): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            return false
        }

        if (!requireBackground || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return true
        }

        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val TAG = "AndroidLocationService"
        private const val CURRENT_LOCATION_TIMEOUT_MILLIS = 8_000L
        private const val LAST_LOCATION_TIMEOUT_MILLIS = 1_500L
        private const val LAST_KNOWN_MAX_AGE_MILLIS = 15 * 60 * 1_000L
    }
}
