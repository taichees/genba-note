import 'package:sqflite/sqflite.dart';

import '../domain/entitlement_state.dart';
import '../domain/subscription_plan.dart';

class EntitlementRepository {
  const EntitlementRepository(this._database);

  final Future<Database> _database;

  static const _planKey = 'subscription_plan';
  static const _productIdKey = 'subscription_product_id';
  static const _pendingKey = 'subscription_pending';
  static const _lastVerifiedAtKey = 'subscription_last_verified_at';
  static const _sourceKey = 'subscription_source';
  static const _debugOverrideKey = 'subscription_debug_override';
  static const _legacyPremiumKey = 'is_premium';

  Future<EntitlementState> fetch() async {
    final db = await _database;
    final rows = await db.query('app_settings');
    final map = <String, String>{
      for (final row in rows)
        row['key'] as String: row['value'] as String,
    };

    final plan = map[_planKey] != null && map[_planKey]!.isNotEmpty
        ? SubscriptionPlan.fromValue(map[_planKey])
        : (map[_legacyPremiumKey] == 'true'
              ? SubscriptionPlan.cloud
              : SubscriptionPlan.free);

    return EntitlementState(
      plan: plan,
      productId: map[_productIdKey],
      purchasePending: map[_pendingKey] == 'true',
      lastVerifiedAt: _parseDate(map[_lastVerifiedAtKey]),
      source: map[_sourceKey] ?? 'local_cache',
      debugOverride: map[_debugOverrideKey] == 'true',
    );
  }

  Future<void> save(EntitlementState state) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _upsert(txn, _planKey, state.plan.value);
      await _upsert(txn, _pendingKey, state.purchasePending.toString());
      await _upsert(txn, _sourceKey, state.source);
      await _upsert(txn, _debugOverrideKey, state.debugOverride.toString());
      await _upsert(txn, _productIdKey, state.productId ?? '');
      await _upsert(
        txn,
        _lastVerifiedAtKey,
        state.lastVerifiedAt?.toIso8601String() ?? '',
      );
    });
  }

  Future<void> _upsert(DatabaseExecutor db, String key, String value) async {
    await db.insert(
      'app_settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toLocal();
  }
}
