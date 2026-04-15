import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../../features/master/data/master_repository.dart';
import '../../features/master/domain/client.dart';
import '../../features/master/domain/property.dart';
import '../../features/work_log/data/location_service.dart';
import '../../features/work_log/data/work_log_repository.dart';
import '../../features/work_log/domain/work_log_detail.dart';
import '../../features/work_log/domain/work_log_filter.dart';
import '../../features/work_log/domain/work_log_list_item.dart';
import '../../features/work_log/domain/work_log_status.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final databaseConnectionProvider = FutureProvider<Database>((ref) async {
  return ref.watch(appDatabaseProvider).open();
});

final workLogRepositoryProvider = Provider<WorkLogRepository>((ref) {
  return WorkLogRepository(ref.watch(databaseConnectionProvider.future));
});

final masterRepositoryProvider = Provider<MasterRepository>((ref) {
  return MasterRepository(ref.watch(databaseConnectionProvider.future));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

final workLogFilterProvider = StateProvider<WorkLogFilter>(
  (ref) => WorkLogFilter.all,
);

final selectedWorkLogIdsProvider = StateProvider<Set<int>>(
  (ref) => <int>{},
);

final workLogListProvider = FutureProvider<List<WorkLogListItem>>((ref) async {
  final filter = ref.watch(workLogFilterProvider);
  final repository = ref.watch(workLogRepositoryProvider);
  return repository.fetchWorkLogs(filter);
});

final workLogDetailProvider = FutureProvider.family<WorkLogDetail?, int>((
  ref,
  workLogId,
) async {
  final repository = ref.watch(workLogRepositoryProvider);
  return repository.fetchWorkLogDetail(workLogId);
});

final clientsProvider = FutureProvider<List<Client>>((ref) async {
  return ref.watch(masterRepositoryProvider).fetchClients();
});

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  return ref.watch(masterRepositoryProvider).fetchProperties();
});

final workLogActionsProvider = Provider<WorkLogActions>((ref) {
  return WorkLogActions(ref);
});

class WorkLogActions {
  WorkLogActions(this._ref);

  final Ref _ref;

  WorkLogRepository get _workLogs => _ref.read(workLogRepositoryProvider);
  MasterRepository get _masters => _ref.read(masterRepositoryProvider);

  Future<void> quickRecord() async {
    final workLogId = await _workLogs.quickRecord();
    _invalidateLists();

    unawaited(_updateLocationInBackground(workLogId));
  }

  Future<void> saveWorkLog({
    required int id,
    int? propertyId,
    int? clientId,
    String? memo,
    required WorkLogStatus status,
  }) async {
    await _workLogs.updateWorkLog(
      id: id,
      propertyId: propertyId,
      clientId: clientId,
      memo: memo,
      status: status,
    );
    _invalidateLists();
    _ref.invalidate(workLogDetailProvider(id));
  }

  Future<int> createClient(String name) async {
    final id = await _masters.createClient(name);
    _ref.invalidate(clientsProvider);
    return id;
  }

  Future<int> createProperty({
    required String name,
    int? clientId,
  }) async {
    final id = await _masters.createProperty(name: name, clientId: clientId);
    _ref.invalidate(propertiesProvider);
    return id;
  }

  Future<void> applyClientToSelected({
    required List<int> ids,
    required int clientId,
  }) async {
    await _masters.applyClientToWorkLogs(workLogIds: ids, clientId: clientId);
    _invalidateLists();
  }

  Future<void> applyPropertyToSelected({
    required List<int> ids,
    required int propertyId,
  }) async {
    await _masters.applyPropertyToWorkLogs(
      workLogIds: ids,
      propertyId: propertyId,
    );
    _invalidateLists();
  }

  Future<void> markSelectedCompleted(List<int> ids) async {
    await _workLogs.markCompleted(ids);
    _invalidateLists();
  }

  Future<void> _updateLocationInBackground(int workLogId) async {
    try {
      final position = await _ref
          .read(locationServiceProvider)
          .tryGetCurrentPosition();
      if (position == null) {
        return;
      }
      await _workLogs.updateLocation(
        workLogId: workLogId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _invalidateLists();
      _ref.invalidate(workLogDetailProvider(workLogId));
    } catch (_) {
      // GPS が取れなくても記録は失敗させない
    }
  }

  void _invalidateLists() {
    _ref.invalidate(workLogListProvider);
  }
}
