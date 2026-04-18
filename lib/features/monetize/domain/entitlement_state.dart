import 'subscription_plan.dart';

class EntitlementState {
  const EntitlementState({
    required this.plan,
    this.productId,
    this.purchasePending = false,
    this.lastVerifiedAt,
    this.source = 'local_cache',
    this.debugOverride = false,
  });

  final SubscriptionPlan plan;
  final String? productId;
  final bool purchasePending;
  final DateTime? lastVerifiedAt;
  final String source;
  final bool debugOverride;

  bool get hasPaidPlan => plan.isPaid;
  bool get hasCloud => plan.hasCloud;

  EntitlementState copyWith({
    SubscriptionPlan? plan,
    String? productId,
    bool? purchasePending,
    DateTime? lastVerifiedAt,
    String? source,
    bool? debugOverride,
  }) {
    return EntitlementState(
      plan: plan ?? this.plan,
      productId: productId ?? this.productId,
      purchasePending: purchasePending ?? this.purchasePending,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      source: source ?? this.source,
      debugOverride: debugOverride ?? this.debugOverride,
    );
  }

  static const empty = EntitlementState(plan: SubscriptionPlan.free);
}
