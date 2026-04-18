import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/db/app_database.dart';
import '../../features/master/data/master_repository.dart';
import '../../features/master/domain/client.dart';
import '../../features/master/domain/property.dart';
import '../../features/monetize/data/billing_service.dart';
import '../../features/monetize/data/cloud_sync_service.dart';
import '../../features/monetize/data/entitlement_repository.dart';
import '../../features/monetize/data/in_app_purchase_billing_service.dart';
import '../../features/monetize/data/paywall_controller.dart';
import '../../features/monetize/domain/entitlement_state.dart';
import '../../features/monetize/domain/feature_gate.dart';
import '../../features/monetize/domain/subscription_plan.dart';
import '../../features/monetize/domain/usage_summary.dart';
import '../../features/work_log/data/address_service.dart';
import '../../features/work_log/data/location_service.dart';
import '../../features/work_log/data/work_log_repository.dart';
import '../../features/work_log/domain/work_log_detail.dart';
import '../../features/work_log/domain/work_log_filter.dart';
import '../../features/work_log/domain/work_log_list_item.dart';
import '../../features/work_log/domain/rough_address_status.dart';
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

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return EntitlementRepository(ref.watch(databaseConnectionProvider.future));
});

final billingServiceProvider = Provider<BillingService>((ref) {
  return InAppPurchaseBillingService();
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  return const PlaceholderCloudSyncService();
});

final paywallControllerProvider =
    StateNotifierProvider<PaywallController, AsyncValue<PaywallState>>((ref) {
      return PaywallController(
        repository: ref.watch(entitlementRepositoryProvider),
        billingService: ref.watch(billingServiceProvider),
      );
    });

final entitlementStateProvider = Provider<EntitlementState>((ref) {
  return ref.watch(paywallControllerProvider).valueOrNull?.entitlement ??
      EntitlementState.empty;
});

final subscriptionPlanProvider = Provider<SubscriptionPlan>((ref) {
  return ref.watch(entitlementStateProvider).plan;
});

final featureGateProvider = Provider<FeatureGate>((ref) {
  return FeatureGate(ref.watch(subscriptionPlanProvider));
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

final addressServiceProvider = Provider<AddressService>((ref) {
  return const AddressService();
});

final workLogFilterProvider = StateProvider<WorkLogFilter>(
  (ref) => WorkLogFilter.all,
);

final selectedWorkLogIdsProvider = StateProvider<Set<int>>(
  (ref) => <int>{},
);

final workLogListByFilterProvider =
    FutureProvider.family<List<WorkLogListItem>, WorkLogFilter>((
  ref,
  filter,
) async {
  final repository = ref.watch(workLogRepositoryProvider);
  return repository.fetchWorkLogs(filter);
});

final workLogListProvider = FutureProvider<List<WorkLogListItem>>((ref) async {
  final filter = ref.watch(workLogFilterProvider);
  return ref.watch(workLogListByFilterProvider(filter).future);
});

final workLogDetailProvider = FutureProvider.family<WorkLogDetail?, int>((
  ref,
  workLogId,
) async {
  final repository = ref.watch(workLogRepositoryProvider);
  return repository.fetchWorkLogDetail(workLogId);
});

final workLogSearchProvider = FutureProvider.family<
    List<WorkLogListItem>,
    ({String query, bool fullAccess})>((ref, params) async {
  if (params.query.trim().isEmpty) {
    return const <WorkLogListItem>[];
  }
  final repository = ref.watch(workLogRepositoryProvider);
  return repository.searchWorkLogs(
    query: params.query,
    fullAccess: params.fullAccess,
  );
});

final clientsProvider = FutureProvider<List<Client>>((ref) async {
  return ref.watch(masterRepositoryProvider).fetchClients();
});

final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  return ref.watch(masterRepositoryProvider).fetchProperties();
});

final usageSummaryProvider = FutureProvider<UsageSummary>((ref) async {
  final workLogs = ref.watch(workLogRepositoryProvider);

  final totalCount = await workLogs.countAll();
  final unsortedCount = await workLogs.countByStatus(WorkLogStatus.unsorted);
  final plan = ref.watch(subscriptionPlanProvider);

  return UsageSummary(
    totalCount: totalCount,
    unsortedCount: unsortedCount,
    plan: plan,
  );
});

final workLogActionsProvider = Provider<WorkLogActions>((ref) {
  return WorkLogActions(ref);
});

final mapInitialCenterProvider = FutureProvider<LatLng>((ref) async {
  final position = await ref
      .read(locationServiceProvider)
      .tryGetCurrentPosition();
  if (position != null) {
    return LatLng(position.latitude, position.longitude);
  }
  return const LatLng(35.6809591, 139.7673068);
});

class WorkLogActions {
  WorkLogActions(this._ref);

  final Ref _ref;

  WorkLogRepository get _workLogs => _ref.read(workLogRepositoryProvider);
  MasterRepository get _masters => _ref.read(masterRepositoryProvider);
  CloudSyncService get _cloudSync => _ref.read(cloudSyncServiceProvider);

  Future<void> prepareLocationPermission() async {
    try {
      await _ref.read(locationServiceProvider).requestPermissionIfNeeded();
    } catch (_) {
      // 権限取得に失敗してもアプリ自体は継続する
    }
  }

  Future<int?> quickRecord() async {
    final usage = await _ref.read(usageSummaryProvider.future);
    if (usage.reachedFreeLimit) {
      return null;
    }

    final workLogId = await _workLogs.quickRecord();
    _invalidateLists();

    unawaited(_updateLocationInBackground(workLogId));
    return workLogId;
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

  Future<void> setDebugPlan(SubscriptionPlan plan) async {
    await _ref.read(paywallControllerProvider.notifier).setDebugPlan(plan);
    _invalidateLists();
  }

  Future<int> deleteOldestWorkLogs({int count = 10}) async {
    final deletedCount = await _workLogs.deleteOldest(count: count);
    _invalidateLists();
    _ref.invalidate(usageSummaryProvider);
    return deletedCount;
  }

  Future<String> cloudSyncStatusLabel() async {
    return _cloudSync.currentStatusLabel();
  }

  Future<void> _updateLocationInBackground(int workLogId) async {
    try {
      final locationService = _ref.read(locationServiceProvider);

      for (var attempt = 0; attempt < 3; attempt++) {
        final position = await locationService.tryGetFreshPosition();
        if (position != null) {
          await _workLogs.updateLocation(
            workLogId: workLogId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          _invalidateLists();
          _ref.invalidate(workLogDetailProvider(workLogId));
          unawaited(
            _enrichAddressInBackground(
              workLogId: workLogId,
              latitude: position.latitude,
              longitude: position.longitude,
            ),
          );
          return;
        }

        if (attempt < 2) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } catch (_) {
      // GPS が取れなくても記録は失敗させない
    }
  }

  Future<void> _enrichAddressInBackground({
    required int workLogId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _workLogs.updateAddressStatus(
        id: workLogId,
        status: RoughAddressStatus.pending,
      );
      _ref.invalidate(workLogDetailProvider(workLogId));

      final address = await _ref
          .read(addressServiceProvider)
          .getRoughAddress(latitude, longitude);

      if (address != null) {
        await _workLogs.updateRoughAddress(id: workLogId, address: address);
      } else {
        await _workLogs.updateAddressStatus(
          id: workLogId,
          status: RoughAddressStatus.failed,
        );
      }
    } catch (_) {
      await _workLogs.updateAddressStatus(
        id: workLogId,
        status: RoughAddressStatus.failed,
      );
    } finally {
      _ref.invalidate(workLogDetailProvider(workLogId));
    }
  }

  void _invalidateLists() {
    _ref.invalidate(workLogListProvider);
    _ref.invalidate(workLogListByFilterProvider);
    _ref.invalidate(usageSummaryProvider);
  }
}
