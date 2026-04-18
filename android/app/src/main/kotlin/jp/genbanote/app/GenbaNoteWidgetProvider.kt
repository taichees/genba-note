package jp.genbanote.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.RemoteViews
import android.widget.Toast
import java.util.concurrent.Executors

class GenbaNoteWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        Log.d(TAG, "onReceive action=${intent.action}")

        if (intent.action != ACTION_QUICK_RECORD) {
            return
        }

        val pendingResult = goAsync()
        EXECUTOR.execute {
            try {
                val quickRecordService = AndroidQuickRecordService(context.applicationContext)
                when (val quickRecordResult = quickRecordService.createQuickRecord()) {
                    is QuickRecordResult.Success -> {
                        Log.d(TAG, "Quick record saved from widget")
                        launchProgressScreen(context, quickRecordResult.workLogId)
                    }
                    QuickRecordResult.FreeLimitReached -> {
                        Log.d(TAG, "Quick record blocked by free limit")
                        showToast(context, context.getString(R.string.widget_free_limit_reached))
                        launchApp(context)
                    }
                    QuickRecordResult.Failure -> {
                        Log.e(TAG, "Quick record failed from widget")
                        showToast(context, context.getString(R.string.widget_record_failed))
                        launchApp(context)
                    }
                }
            } finally {
                AppWidgetManager.getInstance(context).updateAppWidget(
                    ComponentName(context, GenbaNoteWidgetProvider::class.java),
                    buildRemoteViews(context),
                )
                pendingResult.finish()
            }
        }
    }

    companion object {
        const val ACTION_QUICK_RECORD = "jp.genbanote.app.action.QUICK_RECORD"
        private const val TAG = "GenbaNoteWidget"

        private val EXECUTOR = Executors.newSingleThreadExecutor()

        private fun buildRemoteViews(context: Context): RemoteViews {
            val intent = Intent(context, GenbaNoteWidgetProvider::class.java).apply {
                action = ACTION_QUICK_RECORD
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                1001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            return RemoteViews(context.packageName, R.layout.genba_note_widget).apply {
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
        }

        private fun showToast(context: Context, message: String) {
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            }
        }

        private fun launchApp(context: Context) {
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
                ?.apply {
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                }

            if (launchIntent == null) {
                Log.w(TAG, "Failed to resolve launch intent for app")
                return
            }

            context.startActivity(launchIntent)
        }

        private fun launchProgressScreen(context: Context, workLogId: Int) {
            val progressIntent = Intent(context, WidgetRecordProgressActivity::class.java).apply {
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
                putExtra(WidgetRecordProgressActivity.EXTRA_WORK_LOG_ID, workLogId)
            }
            context.startActivity(progressIntent)
        }
    }
}
