import 'feature_gate.dart';
import 'subscription_plan.dart';

class UsageSummary {
  const UsageSummary({
    required this.totalCount,
    required this.unsortedCount,
    required this.plan,
  });

  final int totalCount;
  final int unsortedCount;
  final SubscriptionPlan plan;

  FeatureGate get gate => FeatureGate(plan);

  bool get reachedFreeLimit => plan == SubscriptionPlan.free && totalCount >= 50;
  bool get shouldSuggestPc => plan == SubscriptionPlan.free && unsortedCount >= 20;
  bool get shouldPromptSearchUpgrade => !gate.canUseFullSearch;
}
