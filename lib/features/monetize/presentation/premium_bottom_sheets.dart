import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

Future<void> showUpgradePrompt(
  BuildContext context, {
  required String reason,
  bool canDeleteOldRecords = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '仕事をもっと楽に',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(reason),
              const SizedBox(height: 12),
              const Text('データ無制限'),
              const Text('クラウド保存'),
              const Text('機種変更OK'),
              const Text('PC対応'),
              const SizedBox(height: 20),
              if (canDeleteOldRecords) ...const <Widget>[
                Text('無料プランでは 50 件まで保存できます。'),
                SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/paywall', extra: reason);
                  },
                  child: const Text('プランを見る'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('あとで'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showPcPromoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PCでまとめて整理できます',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text('未整理が増えてきたら、PC対応で一気に片付けられます。'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/paywall', extra: 'PCでまとめて整理できるのは500円プランです。');
                  },
                  child: const Text('有料機能を見る'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                  child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showCloudPromoSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'データを引き継ぐにはクラウド保存が必要です',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text('機種変更や PC 利用に備えるなら、有料プランでクラウド保存を使えます。'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.push('/paywall', extra: '機種変更やクラウド保存は500円プランで使えます。');
                  },
                  child: const Text('有料機能を見る'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('閉じる'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
