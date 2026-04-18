import 'subscription_plan.dart';

class PlanProduct {
  const PlanProduct({
    required this.plan,
    required this.productId,
    required this.title,
    required this.priceLabel,
    required this.description,
    this.rawDetails,
  });

  final SubscriptionPlan plan;
  final String productId;
  final String title;
  final String priceLabel;
  final String description;
  final Object? rawDetails;
}
