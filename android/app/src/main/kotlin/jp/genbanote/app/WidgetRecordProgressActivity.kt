package jp.genbanote.app

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import java.util.concurrent.Executors

class WidgetRecordProgressActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private val repository by lazy { AndroidWorkLogRepository(applicationContext) }
    private val enricher by lazy { AndroidWidgetRecordEnricher(applicationContext) }
    private val executor = Executors.newSingleThreadExecutor()
    private var workLogId: Int = -1
    private var startedAtMillis: Long = 0L
    private var enrichmentStarted = false

    private lateinit var titleView: TextView
    private lateinit var messageView: TextView
    private lateinit var progressBar: ProgressBar

    private val pollRunnable = object : Runnable {
        override fun run() {
            val progress = repository.getWidgetRecordProgress(workLogId)
            if (progress == null) {
                completeAndReturnHome(getString(R.string.widget_record_failed))
                return
            }

            when {
                progress.hasLocation && progress.addressStatus != "pending" -> {
                    completeAndReturnHome(getString(R.string.widget_notification_completed))
                    return
                }
                progress.addressStatus == "failed" -> {
                    completeAndReturnHome(
                        getString(R.string.widget_notification_completed_without_location),
                    )
                    return
                }
                System.currentTimeMillis() - startedAtMillis >= MAX_WAIT_MILLIS -> {
                    completeAndReturnHome(getString(R.string.widget_progress_timed_out))
                    return
                }
                progress.hasLocation -> {
                    messageView.text = getString(R.string.widget_progress_resolving_address)
                }
                else -> {
                    messageView.text = getString(R.string.widget_progress_getting_location)
                }
            }

            handler.postDelayed(this, POLL_INTERVAL_MILLIS)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_widget_record_progress)

        workLogId = intent.getIntExtra(EXTRA_WORK_LOG_ID, -1)
        if (workLogId <= 0) {
            finish()
            return
        }

        startedAtMillis = System.currentTimeMillis()
        titleView = findViewById(R.id.progress_title)
        messageView = findViewById(R.id.progress_message)
        progressBar = findViewById(R.id.progress_indicator)

        titleView.text = getString(R.string.widget_progress_title)
        messageView.text = getString(R.string.widget_progress_getting_location)
        progressBar.isIndeterminate = true
    }

    override fun onStart() {
        super.onStart()
        startForegroundEnrichmentIfNeeded()
        handler.post(pollRunnable)
    }

    override fun onStop() {
        handler.removeCallbacks(pollRunnable)
        super.onStop()
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun showToast(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }

    private fun completeAndReturnHome(message: String) {
        showToast(message)
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }

    private fun startForegroundEnrichmentIfNeeded() {
        if (enrichmentStarted) {
            return
        }
        enrichmentStarted = true

        executor.execute {
            val progress = repository.getWidgetRecordProgress(workLogId)
            val latitude = progress?.latitude
            val longitude = progress?.longitude

            enricher.enrich(
                workLogId = workLogId,
                latitude = latitude,
                longitude = longitude,
                requireBackgroundPermission = false,
            )
        }
    }

    companion object {
        const val EXTRA_WORK_LOG_ID = "work_log_id"
        private const val POLL_INTERVAL_MILLIS = 1_000L
        private const val MAX_WAIT_MILLIS = 30_000L
    }
}
