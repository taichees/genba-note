enum SubscriptionPlan {
  free,
  local,
  cloud;

  String get value => name;

  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return '無料';
      case SubscriptionPlan.local:
        return '100円プラン';
      case SubscriptionPlan.cloud:
        return '500円プラン';
    }
  }

  String get priceLabel {
    switch (this) {
      case SubscriptionPlan.free:
        return '0円';
      case SubscriptionPlan.local:
        return '月額100円';
      case SubscriptionPlan.cloud:
        return '月額500円';
    }
  }

  bool get isPaid => this != SubscriptionPlan.free;
  bool get hasCloud => this == SubscriptionPlan.cloud;

  static SubscriptionPlan fromValue(String? value) {
    for (final plan in values) {
      if (plan.value == value) {
        return plan;
      }
    }
    return SubscriptionPlan.free;
  }
}
