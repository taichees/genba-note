import 'package:sqflite/sqflite.dart';

import '../../work_log/data/work_log_repository.dart';
import '../domain/client.dart';
import '../domain/property.dart';

class MasterRepository {
  const MasterRepository(this._database);

  final Future<Database> _database;

  Future<List<Client>> fetchClients() async {
    final db = await _database;
    final rows = await db.query('clients', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Client.fromMap).toList();
  }

  Future<List<Property>> fetchProperties() async {
    final db = await _database;
    final rows = await db.query('properties', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Property.fromMap).toList();
  }

  Future<int> createClient(String name) async {
    final db = await _database;
    return db.insert('clients', <String, Object?>{'name': name.trim()});
  }

  Future<int> createProperty({
    required String name,
    int? clientId,
  }) async {
    final db = await _database;
    return db.insert('properties', <String, Object?>{
      'name': name.trim(),
      'client_id': clientId,
    });
  }

  Future<void> applyClientToWorkLogs({
    required List<int> workLogIds,
    required int clientId,
  }) async {
    if (workLogIds.isEmpty) {
      return;
    }

    final db = await _database;
    await db.update(
      'work_logs',
      <String, Object?>{'client_id': clientId},
      where: 'id IN (${placeholders(workLogIds.length)})',
      whereArgs: workLogIds,
    );
  }

  Future<void> applyPropertyToWorkLogs({
    required List<int> workLogIds,
    required int propertyId,
  }) async {
    if (workLogIds.isEmpty) {
      return;
    }

    final db = await _database;
    final propertyRow = await db.query(
      'properties',
      columns: <String>['client_id'],
      where: 'id = ?',
      whereArgs: <Object?>[propertyId],
      limit: 1,
    );
    final clientId =
        propertyRow.isEmpty ? null : propertyRow.first['client_id'] as int?;

    await db.update(
      'work_logs',
      <String, Object?>{
        'property_id': propertyId,
        'client_id': clientId,
      },
      where: 'id IN (${placeholders(workLogIds.length)})',
      whereArgs: workLogIds,
    );
  }
}
