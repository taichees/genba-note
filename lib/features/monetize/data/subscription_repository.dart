import 'package:sqflite/sqflite.dart';

class SubscriptionRepository {
  const SubscriptionRepository(this._database);

  static const premiumKey = 'is_premium';

  final Future<Database> _database;

  Future<bool> fetchIsPremium() async {
    final db = await _database;
    final rows = await db.query(
      'app_settings',
      columns: const <String>['value'],
      where: 'key = ?',
      whereArgs: const <Object?>[premiumKey],
      limit: 1,
    );

    if (rows.isEmpty) {
      return false;
    }

    return rows.first['value'] == 'true';
  }

  Future<void> setIsPremium(bool value) async {
    final db = await _database;
    await db.insert(
      'app_settings',
      <String, Object?>{
        'key': premiumKey,
        'value': value.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
