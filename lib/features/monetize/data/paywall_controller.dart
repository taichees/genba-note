import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/billing_product_ids.dart';
import '../domain/entitlement_state.dart';
import '../domain/plan_product.dart';
import '../domain/subscription_plan.dart';
import 'billing_service.dart';
import 'entitlement_repository.dart';

class PaywallState {
  const PaywallState({
    required this.entitlement,
    this.products = const <PlanProduct>[],
    this.storeAvailable = false,
    this.loading = false,
    this.message,
  });

  final EntitlementState entitlement;
  final List<PlanProduct> products;
  final bool storeAvailable;
  final bool loading;
  final String? message;

  PaywallState copyWith({
    EntitlementState? entitlement,
    List<PlanProduct>? products,
    bool? storeAvailable,
    bool? loading,
    String? message,
    bool clearMessage = false,
  }) {
    return PaywallState(
      entitlement: entitlement ?? this.entitlement,
      products: products ?? this.products,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      loading: loading ?? this.loading,
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  static const initial = PaywallState(entitlement: EntitlementState.empty);
}

class PaywallController extends StateNotifier<AsyncValue<PaywallState>> {
  PaywallController({
    required EntitlementRepository repository,
    required BillingService billingService,
  })  : _repository = repository,
        _billingService = billingService,
        super(const AsyncValue.loading()) {
    _subscription = _billingService.purchaseStream.listen(_handlePurchases);
    unawaited(initialize());
  }

  final EntitlementRepository _repository;
  final BillingService _billingService;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> initialize() async {
    try {
      final entitlement = await _repository.fetch();
      final storeAvailable = await _billingService.isAvailable();
      final products = storeAvailable
          ? await _billingService.queryProducts()
          : _fallbackProducts;

      state = AsyncValue.data(
        PaywallState(
          entitlement: entitlement,
          storeAvailable: storeAvailable,
          products: products.isEmpty ? _fallbackProducts : products,
        ),
      );

      if (storeAvailable) {
        unawaited(_billingService.restorePurchases());
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> purchasePlan(SubscriptionPlan plan) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    PlanProduct? product;
    for (final item in current.products) {
      if (item.plan == plan) {
        product = item;
        break;
      }
    }
    if (product == null) {
      state = AsyncValue.data(
        current.copyWith(message: '商品情報が見つかりません'),
      );
      return;
    }

    state = AsyncValue.data(current.copyWith(loading: true, clearMessage: true));

    try {
      final pending = current.entitlement.copyWith(
        purchasePending: true,
        source: 'purchase_flow',
      );
      await _repository.save(pending);
      state = AsyncValue.data(current.copyWith(entitlement: pending, loading: true));
      await _billingService.buy(product);
    } catch (error) {
      final reverted = current.entitlement.copyWith(purchasePending: false);
      await _repository.save(reverted);
      state = AsyncValue.data(
        current.copyWith(
          entitlement: reverted,
          loading: false,
          message: '購入開始に失敗しました: $error',
        ),
      );
    }
  }

  Future<void> restore() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncValue.data(current.copyWith(loading: true, clearMessage: true));
    try {
      await _billingService.restorePurchases();
      state = AsyncValue.data(
        (state.valueOrNull ?? current).copyWith(
          loading: false,
          message: '購入の復元を実行しました',
        ),
      );
    } catch (error) {
      state = AsyncValue.data(
        current.copyWith(loading: false, message: '復元に失敗しました: $error'),
      );
    }
  }

  Future<void> setDebugPlan(SubscriptionPlan plan) async {
    final current = state.valueOrNull ?? PaywallState.initial;
    final next = current.entitlement.copyWith(
      plan: plan,
      productId: _productIdForPlan(plan),
      purchasePending: false,
      lastVerifiedAt: DateTime.now(),
      source: 'debug_panel',
      debugOverride: true,
    );
    await _repository.save(next);
    state = AsyncValue.data(
      current.copyWith(
        entitlement: next,
        message: 'デバッグ用に ${plan.label} へ切り替えました',
      ),
    );
  }

  Future<void> clearDebugOverride() async {
    final current = state.valueOrNull ?? PaywallState.initial;
    final persisted = await _repository.fetch();
    final next = persisted.copyWith(debugOverride: false);
    await _repository.save(next);
    state = AsyncValue.data(
      current.copyWith(
        entitlement: next,
        message: 'デバッグ上書きを解除しました',
      ),
    );
  }

  void clearMessage() {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }
    state = AsyncValue.data(current.copyWith(clearMessage: true));
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    final current = state.valueOrNull ?? PaywallState.initial;
    var nextState = current;

    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.pending) {
        final pending = nextState.entitlement.copyWith(
          purchasePending: true,
          source: 'purchase_pending',
        );
        await _repository.save(pending);
        nextState = nextState.copyWith(entitlement: pending, loading: true);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final plan = _planFromProductId(purchase.productID);
        if (plan != null) {
          final entitlement = nextState.entitlement.copyWith(
            plan: plan,
            productId: purchase.productID,
            purchasePending: false,
            lastVerifiedAt: DateTime.now(),
            source: purchase.status == PurchaseStatus.restored
                ? 'restore_purchase'
                : 'play_billing',
            debugOverride: false,
          );
          await _repository.save(entitlement);
          nextState = nextState.copyWith(
            entitlement: entitlement,
            loading: false,
            message: purchase.status == PurchaseStatus.restored
                ? '購入を復元しました'
                : '購入が完了しました',
          );
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        final reverted = nextState.entitlement.copyWith(purchasePending: false);
        await _repository.save(reverted);
        nextState = nextState.copyWith(
          entitlement: reverted,
          loading: false,
          message: purchase.status == PurchaseStatus.error
              ? '購入に失敗しました'
              : '購入をキャンセルしました',
        );
      }

      if (purchase.pendingCompletePurchase) {
        await _billingService.completePurchase(purchase);
      }
    }

    state = AsyncValue.data(nextState);
  }

  SubscriptionPlan? _planFromProductId(String productId) {
    return switch (productId) {
      BillingProductIds.localMonthly => SubscriptionPlan.local,
      BillingProductIds.cloudMonthly => SubscriptionPlan.cloud,
      _ => null,
    };
  }

  String? _productIdForPlan(SubscriptionPlan plan) {
    return switch (plan) {
      SubscriptionPlan.free => null,
      SubscriptionPlan.local => BillingProductIds.localMonthly,
      SubscriptionPlan.cloud => BillingProductIds.cloudMonthly,
    };
  }

  List<PlanProduct> get _fallbackProducts => const <PlanProduct>[
        PlanProduct(
          plan: SubscriptionPlan.local,
          productId: BillingProductIds.localMonthly,
          title: '100円プラン',
          priceLabel: '月額100円',
          description: 'スマホ内で履歴無制限。写真もローカル保存で使えます。',
        ),
        PlanProduct(
          plan: SubscriptionPlan.cloud,
          productId: BillingProductIds.cloudMonthly,
          title: '500円プラン',
          priceLabel: '月額500円',
          description: 'クラウド同期、WEB利用、月次集計。初月無料トライアル前提。',
        ),
      ];

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
