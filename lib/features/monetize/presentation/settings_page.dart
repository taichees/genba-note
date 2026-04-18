import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/app_providers.dart';
import '../domain/subscription_plan.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _debugTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final entitlement = ref.watch(entitlementStateProvider);
    final gate = ref.watch(featureGateProvider);
    final cloudStatus = ref.watch(_cloudStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('現在のプラン'),
                  subtitle: Text(entitlement.plan.label),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/paywall'),
                ),
                ListTile(
                  leading: const Icon(Icons.compare_arrows),
                  title: const Text('プラン比較を見る'),
                  subtitle: const Text('100円 / 500円プランの違いを確認'),
                  onTap: () => context.push('/paywall'),
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('購入を復元'),
                  onTap: () =>
                      ref.read(paywallControllerProvider.notifier).restore(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: const Text('クラウド同期'),
                  subtitle: Text(
                    gate.canUseCloudSync
                        ? (cloudStatus.valueOrNull ?? '確認中')
                        : '500円プランで利用できます',
                  ),
                ),
                const ListTile(
                  leading: Icon(Icons.desktop_windows_outlined),
                  title: Text('WEB利用'),
                  subtitle: Text('500円プランで利用できます'),
                ),
                const ListTile(
                  leading: Icon(Icons.search),
                  title: Text('フル検索'),
                  subtitle: Text('500円プランで履歴全件を対象に検索できます'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('利用規約'),
                  subtitle: const Text('プレースホルダ'),
                  onTap: () => _showTextDialog(
                    context,
                    title: '利用規約',
                    body: '利用規約の正式版は公開前に差し替えます。',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('プライバシーポリシー'),
                  subtitle: const Text('プレースホルダ'),
                  onTap: () => _showTextDialog(
                    context,
                    title: 'プライバシーポリシー',
                    body: 'プライバシーポリシーの正式版は公開前に差し替えます。',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('お問い合わせ先'),
                  subtitle: const Text('support@example.com'),
                  onTap: () => _showTextDialog(
                    context,
                    title: 'お問い合わせ先',
                    body: 'support@example.com',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              title: const Text('Version 0.1.0+1'),
              subtitle: Text(
                entitlement.lastVerifiedAt == null
                    ? '課金状態未確認'
                    : '最終確認: ${entitlement.lastVerifiedAt}',
              ),
              onTap: _onVersionTap,
            ),
          ),
        ],
      ),
    );
  }

  void _onVersionTap() {
    _debugTapCount += 1;
    if (_debugTapCount < 7) {
      return;
    }
    _debugTapCount = 0;
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _DebugPanel(
        onSelectPlan: (plan) async {
          await ref.read(workLogActionsProvider).setDebugPlan(plan);
          if (mounted) {
            navigator.pop();
          }
        },
      ),
    );
  }

  void _showTextDialog(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

final _cloudStatusProvider = FutureProvider<String>((ref) async {
  return ref.read(workLogActionsProvider).cloudSyncStatusLabel();
});

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.onSelectPlan});

  final Future<void> Function(SubscriptionPlan plan) onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Debug Plan Panel', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...SubscriptionPlan.values.map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onSelectPlan(plan),
                    child: Text(plan.label),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
