import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/plan_product.dart';

abstract class BillingService {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<List<PlanProduct>> queryProducts();

  Future<void> buy(PlanProduct product);

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}
