import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/constants/billing_product_ids.dart';
import '../domain/plan_product.dart';
import '../domain/subscription_plan.dart';
import 'billing_service.dart';

class InAppPurchaseBillingService implements BillingService {
  InAppPurchaseBillingService({InAppPurchase? instance})
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<List<PlanProduct>> queryProducts() async {
    final response = await _instance.queryProductDetails(
      BillingProductIds.all,
    );

    final products = response.productDetails.map(_toPlanProduct).toList();
    products.sort((a, b) => a.plan.index.compareTo(b.plan.index));
    return products;
  }

  @override
  Future<void> buy(PlanProduct product) async {
    final details = product.rawDetails;
    if (details is! ProductDetails) {
      throw StateError('購入情報が見つかりません');
    }

    final purchaseParam = PurchaseParam(productDetails: details);
    await _instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> restorePurchases() => _instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _instance.completePurchase(purchase);
  }

  PlanProduct _toPlanProduct(ProductDetails details) {
    final plan = switch (details.id) {
      BillingProductIds.localMonthly => SubscriptionPlan.local,
      BillingProductIds.cloudMonthly => SubscriptionPlan.cloud,
      _ => SubscriptionPlan.free,
    };

    return PlanProduct(
      plan: plan,
      productId: details.id,
      title: details.title,
      priceLabel: details.price,
      description: details.description,
      rawDetails: details,
    );
  }
}
