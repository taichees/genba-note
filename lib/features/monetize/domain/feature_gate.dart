import 'subscription_plan.dart';

class FeatureGate {
  const FeatureGate(this.plan);

  final SubscriptionPlan plan;

  bool get canRecordUnlimited => plan != SubscriptionPlan.free;
  bool get canUseCloudSync => plan == SubscriptionPlan.cloud;
  bool get canUseWeb => plan == SubscriptionPlan.cloud;
  bool get canUseFullSearch => plan == SubscriptionPlan.cloud;
  bool get canUseBulkEdit => plan == SubscriptionPlan.cloud;
  bool get canUseFullHistoryMap => plan == SubscriptionPlan.cloud;
  bool get canUseUnlimitedPhotos => plan != SubscriptionPlan.free;
  bool get canUseBackup => plan == SubscriptionPlan.cloud;
}
