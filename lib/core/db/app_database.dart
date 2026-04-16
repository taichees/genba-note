import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase();

  static const _databaseName = 'genba_note.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> open() async {
    if (_database != null) {
      return _database!;
    }

    final directory = await getApplicationSupportDirectory();
    final databasePath = '${directory.path}/$_databaseName';

    _database = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createSchema(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS masters');
      await db.execute('DROP TABLE IF EXISTS work_logs');
      await db.execute('DROP TABLE IF EXISTS properties');
      await db.execute('DROP TABLE IF EXISTS clients');
      await _createSchema(db);
      return;
    }

    if (oldVersion < 3) {
      await _createAppSettingsTable(db);
    }
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE properties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        client_id INTEGER,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE work_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        datetime TEXT NOT NULL,
        latitude REAL,
        longitude REAL,
        property_id INTEGER,
        client_id INTEGER,
        memo TEXT,
        status TEXT NOT NULL,
        FOREIGN KEY (property_id) REFERENCES properties (id) ON DELETE SET NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE SET NULL
      )
    ''');

    await _createAppSettingsTable(db);
  }

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
