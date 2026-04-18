import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_time_label.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../monetize/presentation/premium_bottom_sheets.dart';

class WorkLogSearchPage extends ConsumerStatefulWidget {
  const WorkLogSearchPage({super.key});

  @override
  ConsumerState<WorkLogSearchPage> createState() => _WorkLogSearchPageState();
}

class _WorkLogSearchPageState extends ConsumerState<WorkLogSearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(subscriptionPlanProvider);
    final gate = ref.watch(featureGateProvider);
    final resultsState = ref.watch(
      workLogSearchProvider((query: _query, fullAccess: gate.canUseFullSearch)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('検索')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: gate.canUseFullSearch
                    ? 'メモ、住所、物件名、請求先で検索'
                    : '物件名や請求先で簡易検索',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _runSearch,
            ),
            const SizedBox(height: 12),
            if (!gate.canUseFullSearch)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('500円プランでフル検索'),
                  subtitle: const Text('住所・メモ・全履歴検索はクラウドプランで利用できます'),
                  trailing: FilledButton(
                    onPressed: () => showUpgradePrompt(
                      context,
                      reason: '検索から詳しく探したいときは、500円プランのフル検索が便利です。',
                    ),
                    child: const Text('見る'),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('現在のプラン: ${plan.label}'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _query.isEmpty
                  ? const Center(child: Text('検索語を入力してください'))
                  : resultsState.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return const Center(child: Text('該当する記録がありません'));
                        }
                        return ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return ListTile(
                              title: Text(item.datetime.toShortLabel()),
                              subtitle: Text(item.propertyName ?? item.clientName ?? '未設定'),
                              onTap: () => context.push('/work-logs/${item.id}'),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('検索に失敗しました: $error')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _runSearch(String value) {
    setState(() => _query = value.trim());
  }
}
