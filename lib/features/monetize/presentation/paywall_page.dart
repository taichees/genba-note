import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/app_providers.dart';
import '../data/paywall_controller.dart';
import '../domain/feature_gate.dart';
import '../domain/plan_product.dart';
import '../domain/subscription_plan.dart';

class PaywallPage extends ConsumerWidget {
  const PaywallPage({super.key, this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywallState = ref.watch(paywallControllerProvider);
    final controller = ref.read(paywallControllerProvider.notifier);
    final currentPlan = ref.watch(subscriptionPlanProvider);
    final gate = ref.watch(featureGateProvider);

    ref.listen<AsyncValue<PaywallState>>(paywallControllerProvider, (
      previous,
      next,
    ) {
      final message = next.valueOrNull?.message;
      if (message == null || message == previous?.valueOrNull?.message) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      controller.clearMessage();
    });

    final state = paywallState.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('プラン比較')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (reason != null) ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(reason!),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _CurrentPlanCard(plan: currentPlan, gate: gate),
          const SizedBox(height: 16),
          ...SubscriptionPlan.values.map(
            (plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlanCard(
                plan: plan,
                currentPlan: currentPlan,
                paywallState: state,
                onPurchase: plan == SubscriptionPlan.free
                    ? null
                    : () => controller.purchasePlan(plan),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: state?.loading == true ? null : controller.restore,
            icon: const Icon(Icons.restore),
            label: const Text('購入を復元'),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const <Widget>[
                  Text('500円プランで使えること', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('クラウド同期あり'),
                  Text('WEB利用可能'),
                  Text('地図全履歴'),
                  Text('一括編集'),
                  Text('月次集計'),
                  SizedBox(height: 8),
                  Text('初月無料トライアルは Play Console 側で設定します。'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.plan, required this.gate});

  final SubscriptionPlan plan;
  final FeatureGate gate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('現在のプラン', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(plan.label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(gate.canUseCloudSync ? 'クラウド同期が利用できます' : 'ローカルファーストで利用中です'),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.currentPlan,
    required this.paywallState,
    required this.onPurchase,
  });

  final SubscriptionPlan plan;
  final SubscriptionPlan currentPlan;
  final PaywallState? paywallState;
  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    PlanProduct? matchedProduct;
    for (final product in paywallState?.products ?? const <PlanProduct>[]) {
      if (product.plan == plan) {
        matchedProduct = product;
        break;
      }
    }
    final isCurrent = currentPlan == plan;

    final benefits = switch (plan) {
      SubscriptionPlan.free => const <String>[
          'ローカル保存',
          '履歴は50件まで',
          '簡易検索',
        ],
      SubscriptionPlan.local => const <String>[
          '履歴無制限',
          '写真無制限（ローカル）',
          '機種変更引き継ぎなし',
        ],
      SubscriptionPlan.cloud => const <String>[
          '履歴無制限',
          'クラウド同期',
          'WEB利用 / フル検索 / 一括編集',
        ],
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(plan.label, style: Theme.of(context).textTheme.titleLarge),
                ),
                if (isCurrent) const Chip(label: Text('利用中')),
              ],
            ),
            const SizedBox(height: 8),
            Text(matchedProduct?.priceLabel ?? plan.priceLabel),
            const SizedBox(height: 8),
            ...benefits.map(Text.new),
            const SizedBox(height: 12),
            if (!isCurrent)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: paywallState?.loading == true ? null : onPurchase,
                  child: Text(plan == SubscriptionPlan.cloud ? '500円プランを購入' : '100円プランを購入'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
