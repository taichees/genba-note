package jp.genbanote.app

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

class AndroidWorkLogRepository(context: Context) {
    private val dbHelper = GenbaNoteDatabaseHelper(context)

    fun countWorkLogs(): Int {
        val db = dbHelper.readableDatabase
        db.rawQuery("SELECT COUNT(*) FROM work_logs", null).use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getInt(0)
            }
        }
        return 0
    }

    fun hasPaidPlan(): Boolean {
        val db = dbHelper.readableDatabase
        db.rawQuery(
            "SELECT value FROM app_settings WHERE key = ? LIMIT 1",
            arrayOf("subscription_plan"),
        ).use { cursor ->
            if (cursor.moveToFirst()) {
                val value = cursor.getString(0)
                return value == "local" || value == "cloud"
            }
        }
        return false
    }

    fun insertQuickRecord(latitude: Double?, longitude: Double?): Int {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("datetime", LocalDateTime.now().format(DATE_TIME_FORMATTER))
            put("status", "unsorted")
            if (latitude != null) {
                put("latitude", latitude)
            } else {
                putNull("latitude")
            }
            if (longitude != null) {
                put("longitude", longitude)
            } else {
                putNull("longitude")
            }
            putNull("rough_address")
            putNull("rough_address_status")
            putNull("rough_address_updated_at")
            putNull("property_id")
            putNull("client_id")
            putNull("memo")
        }
        return db.insertOrThrow("work_logs", null, values).toInt()
    }

    fun updateRoughAddress(id: Int, address: String) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("rough_address", address)
            put("rough_address_status", "success")
            put("rough_address_updated_at", LocalDateTime.now().format(DATE_TIME_FORMATTER))
        }
        db.update("work_logs", values, "id = ?", arrayOf(id.toString()))
    }

    fun updateAddressStatus(id: Int, status: String) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            put("rough_address_status", status)
            put("rough_address_updated_at", LocalDateTime.now().format(DATE_TIME_FORMATTER))
        }
        db.update("work_logs", values, "id = ?", arrayOf(id.toString()))
    }

    fun updateLocation(id: Int, latitude: Double?, longitude: Double?) {
        val db = dbHelper.writableDatabase
        val values = ContentValues().apply {
            if (latitude != null) {
                put("latitude", latitude)
            } else {
                putNull("latitude")
            }
            if (longitude != null) {
                put("longitude", longitude)
            } else {
                putNull("longitude")
            }
        }
        db.update("work_logs", values, "id = ?", arrayOf(id.toString()))
    }

    fun getWidgetRecordProgress(id: Int): WidgetRecordProgress? {
        val db = dbHelper.readableDatabase
        db.rawQuery(
            """
            SELECT latitude, longitude, rough_address_status, rough_address
            FROM work_logs
            WHERE id = ?
            LIMIT 1
            """.trimIndent(),
            arrayOf(id.toString()),
        ).use { cursor ->
            if (!cursor.moveToFirst()) {
                return null
            }

            return WidgetRecordProgress(
                latitude = cursor.getNullableDouble(0),
                longitude = cursor.getNullableDouble(1),
                addressStatus = cursor.getString(2),
                roughAddress = cursor.getString(3),
            )
        }
    }
}

data class WidgetRecordProgress(
    val latitude: Double?,
    val longitude: Double?,
    val addressStatus: String?,
    val roughAddress: String?,
) {
    val hasLocation: Boolean
        get() = latitude != null && longitude != null

    val isFinished: Boolean
        get() = addressStatus == "success" || addressStatus == "failed"
}

private class GenbaNoteDatabaseHelper(context: Context) : SQLiteOpenHelper(
    context,
    "${context.filesDir.path}/genba_note.db",
    null,
    DATABASE_VERSION,
) {
    override fun onCreate(db: SQLiteDatabase) {
        createSchema(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("DROP TABLE IF EXISTS work_logs")
            db.execSQL("DROP TABLE IF EXISTS properties")
            db.execSQL("DROP TABLE IF EXISTS clients")
            db.execSQL("DROP TABLE IF EXISTS app_settings")
            createSchema(db)
            return
        }

        if (oldVersion < 3) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS app_settings (
                  key TEXT PRIMARY KEY,
                  value TEXT NOT NULL
                )
                """.trimIndent(),
            )
        }

        if (oldVersion < 4) {
            db.execSQL("ALTER TABLE work_logs ADD COLUMN rough_address TEXT")
            db.execSQL("ALTER TABLE work_logs ADD COLUMN rough_address_status TEXT")
            db.execSQL("ALTER TABLE work_logs ADD COLUMN rough_address_updated_at TEXT")
        }
    }

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE clients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL
            )
            """.trimIndent(),
        )

        db.execSQL(
            """
            CREATE TABLE properties (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              client_id INTEGER,
              FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL
            )
            """.trimIndent(),
        )

        db.execSQL(
            """
            CREATE TABLE work_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              datetime TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              rough_address TEXT,
              rough_address_status TEXT,
              rough_address_updated_at TEXT,
              property_id INTEGER,
              client_id INTEGER,
              memo TEXT,
              status TEXT NOT NULL,
              FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE SET NULL,
              FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL
            )
            """.trimIndent(),
        )

        db.execSQL(
            """
            CREATE TABLE app_settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
            """.trimIndent(),
        )
    }

    companion object {
        private const val DATABASE_VERSION = 4
    }
}

private val DATE_TIME_FORMATTER: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSSSSS")

private fun android.database.Cursor.getNullableDouble(index: Int): Double? {
    if (isNull(index)) {
        return null
    }
    return getDouble(index)
}
