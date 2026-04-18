package jp.genbanote.app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    requestNotificationPermissionIfNeeded()
                    result.success(null)
                }
                "requestBackgroundLocationPermission" -> {
                    requestBackgroundLocationPermissionIfNeeded()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestBackgroundLocationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return
        }

        val foregroundGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED || ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!foregroundGranted) {
            return
        }

        val alreadyGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_BACKGROUND_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return
        }

        val alreadyGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            return
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    companion object {
        private const val SYSTEM_CHANNEL = "jp.genbanote.app/system"
        private const val BACKGROUND_LOCATION_PERMISSION_REQUEST_CODE = 2000
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 2001
    }
}
