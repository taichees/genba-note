import 'package:sqflite/sqflite.dart';

import '../domain/work_log.dart';
import '../domain/work_log_detail.dart';
import '../domain/work_log_filter.dart';
import '../domain/work_log_list_item.dart';
import '../domain/work_log_status.dart';

class WorkLogRepository {
  const WorkLogRepository(this._database);

  final Future<Database> _database;

  Future<List<WorkLogListItem>> fetchWorkLogs(WorkLogFilter filter) async {
    final db = await _database;
    final whereClause =
        filter == WorkLogFilter.unsorted ? "WHERE wl.status = 'unsorted'" : '';
    final rows = await db.rawQuery('''
      SELECT
        wl.id,
        wl.datetime,
        wl.status,
        wl.latitude,
        wl.longitude,
        wl.property_id,
        wl.client_id,
        p.name AS property_name,
        c.name AS client_name
      FROM work_logs wl
      LEFT JOIN properties p ON p.id = wl.property_id
      LEFT JOIN clients c ON c.id = wl.client_id
      $whereClause
      ORDER BY wl.datetime DESC, wl.id DESC
    ''');
    return rows.map(WorkLogListItem.fromMap).toList();
  }

  Future<WorkLogDetail?> fetchWorkLogDetail(int id) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT
        wl.*,
        p.name AS property_name,
        c.name AS client_name
      FROM work_logs wl
      LEFT JOIN properties p ON p.id = wl.property_id
      LEFT JOIN clients c ON c.id = wl.client_id
      WHERE wl.id = ?
      LIMIT 1
    ''', <Object?>[id]);

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return WorkLogDetail(
      workLog: WorkLog.fromMap(row),
      propertyName: row['property_name'] as String?,
      clientName: row['client_name'] as String?,
    );
  }

  Future<int> quickRecord() async {
    final db = await _database;
    return db.insert('work_logs', <String, Object?>{
      'datetime': DateTime.now().toIso8601String(),
      'status': WorkLogStatus.unsorted.value,
    });
  }

  Future<int> countAll() async {
    final db = await _database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM work_logs'),
    );
    return result ?? 0;
  }

  Future<int> countByStatus(WorkLogStatus status) async {
    final db = await _database;
    final result = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM work_logs WHERE status = ?',
        <Object?>[status.value],
      ),
    );
    return result ?? 0;
  }

  Future<int> deleteOldest({int count = 10}) async {
    final db = await _database;
    return db.delete(
      'work_logs',
      where: '''
        id IN (
          SELECT id
          FROM work_logs
          ORDER BY datetime ASC, id ASC
          LIMIT ?
        )
      ''',
      whereArgs: <Object?>[count],
    );
  }

  Future<void> updateLocation({
    required int workLogId,
    double? latitude,
    double? longitude,
  }) async {
    final db = await _database;
    await db.update(
      'work_logs',
      <String, Object?>{
        'latitude': latitude,
        'longitude': longitude,
      },
      where: 'id = ?',
      whereArgs: <Object?>[workLogId],
    );
  }

  Future<void> updateWorkLog({
    required int id,
    int? propertyId,
    int? clientId,
    String? memo,
    required WorkLogStatus status,
  }) async {
    final db = await _database;
    await db.update(
      'work_logs',
      <String, Object?>{
        'property_id': propertyId,
        'client_id': clientId,
        'memo': normalizeText(memo),
        'status': status.value,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markCompleted(List<int> workLogIds) async {
    if (workLogIds.isEmpty) {
      return;
    }

    final db = await _database;
    await db.update(
      'work_logs',
      <String, Object?>{'status': WorkLogStatus.completed.value},
      where: 'id IN (${placeholders(workLogIds.length)})',
      whereArgs: workLogIds,
    );
  }
}

String placeholders(int count) => List<String>.filled(count, '?').join(', ');

String? normalizeText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
