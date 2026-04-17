import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_time_label.dart';
import '../../../core/utils/system_channels.dart';
import '../../../shared/providers/app_providers.dart';
import '../../master/domain/client.dart';
import '../../master/domain/property.dart';
import '../../monetize/presentation/premium_bottom_sheets.dart';
import '../domain/work_log_filter.dart';
import '../domain/work_log_status.dart';
import 'widgets/master_picker_bottom_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  bool _isRecording = false;
  bool _isApplyingBulk = false;
  bool _didShowPcPromo = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workLogActionsProvider).prepareLocationPermission();
      AppSystemChannels.requestNotificationPermissionIfNeeded();
      _checkUsagePrompts();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    _refreshHomeData();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }

    final filter = _tabController.index == 0
        ? WorkLogFilter.all
        : WorkLogFilter.unsorted;
    ref.read(workLogFilterProvider.notifier).state = filter;
    ref.read(selectedWorkLogIdsProvider.notifier).state = <int>{};
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(workLogListProvider);
    final usageSummary = ref.watch(usageSummaryProvider).valueOrNull;
    final selectedIds = ref.watch(selectedWorkLogIdsProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final properties =
        ref.watch(propertiesProvider).valueOrNull ?? const <Property>[];
    final selectionMode = _tabController.index == 1 && selectedIds.isNotEmpty;
    final isPremium = usageSummary?.isPremium ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectionMode ? '${selectedIds.length}件選択中' : AppStrings.appTitle),
        actions: selectionMode
            ? <Widget>[
                IconButton(
                  tooltip: '請求先を設定',
                  onPressed: _isApplyingBulk
                      ? null
                      : () => _applyClientBulk(context, clients, selectedIds.toList()),
                  icon: const Icon(Icons.receipt_long),
                ),
                IconButton(
                  tooltip: '物件を設定',
                  onPressed: _isApplyingBulk
                      ? null
                      : () => _applyPropertyBulk(
                            context,
                            properties,
                            clients,
                            selectedIds.toList(),
                          ),
                  icon: const Icon(Icons.home_work_outlined),
                ),
                IconButton(
                  tooltip: '完了にする',
                  onPressed: _isApplyingBulk
                      ? null
                      : () => _markSelectedCompleted(selectedIds.toList()),
                  icon: const Icon(Icons.done_all),
                ),
              ]
            : <Widget>[
                IconButton(
                  tooltip: '引き継ぎ',
                  onPressed: () => _showCloudPromo(context),
                  icon: const Icon(Icons.cloud_outlined),
                ),
                IconButton(
                  tooltip: isPremium ? 'プレミアム利用中' : '有料プラン',
                  onPressed: () => _showPremiumOffer(context),
                  icon: Icon(
                    isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
                  ),
                ),
                IconButton(
                  tooltip: '地図を見る',
                  onPressed: () => context.push('/map'),
                  icon: const Icon(Icons.map_outlined),
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Tab>[
            Tab(text: 'すべて'),
            Tab(text: '未整理'),
          ],
        ),
      ),
      body: listState.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('まだ記録がありません'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final showCheckbox = _tabController.index == 1;
              final selected = selectedIds.contains(item.id);

              return ListTile(
                leading: showCheckbox
                    ? Checkbox(
                        value: selected,
                        onChanged: (_) => _toggleSelection(item.id),
                      )
                    : null,
                title: Text(item.datetime.toShortLabel()),
                subtitle: Text(item.propertyName ?? AppStrings.unassigned),
                trailing: _StatusChip(status: item.status),
                onTap: () => context.push('/work-logs/${item.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('読込に失敗しました: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isRecording ? null : () => _quickRecord(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _checkUsagePrompts() async {
    if (!mounted || _didShowPcPromo) {
      return;
    }

    final usage = await ref.read(usageSummaryProvider.future);
    if (!mounted || !usage.shouldSuggestPc) {
      return;
    }

    _didShowPcPromo = true;
    final wantsPremium = await showPcPromoSheet(context);
    if (wantsPremium == true && mounted) {
      await _showPremiumOffer(context);
    }
  }

  void _refreshHomeData() {
    ref.invalidate(workLogListProvider);
    ref.invalidate(workLogListByFilterProvider(WorkLogFilter.all));
    ref.invalidate(workLogListByFilterProvider(WorkLogFilter.unsorted));
    ref.invalidate(usageSummaryProvider);
  }

  void _toggleSelection(int id) {
    final current = ref.read(selectedWorkLogIdsProvider);
    final next = <int>{...current};
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    ref.read(selectedWorkLogIdsProvider.notifier).state = next;
  }

  Future<void> _quickRecord(BuildContext context) async {
    setState(() => _isRecording = true);
    final workLogId = await ref.read(workLogActionsProvider).quickRecord();
    if (workLogId == null) {
      if (!context.mounted) {
        return;
      }
      await _showRecordLimitPrompt(context);
      setState(() => _isRecording = false);
      return;
    }
    await HapticFeedback.lightImpact();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('記録しました'),
          duration: Duration(milliseconds: 1200),
        ),
      );
    setState(() => _isRecording = false);
    _checkUsagePrompts();
  }

  Future<void> _showRecordLimitPrompt(BuildContext context) async {
    final action = await showRecordLimitSheet(context);
    if (!context.mounted || action == null) {
      return;
    }

    if (action == 'delete') {
      final deletedCount = await ref
          .read(workLogActionsProvider)
          .deleteOldestWorkLogs();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$deletedCount件の古い記録を削除しました')),
        );
      return;
    }

    await _showPremiumOffer(context);
  }

  Future<void> _showPremiumOffer(BuildContext context) async {
    final shouldUpgrade = await showPremiumOfferSheet(context);
    if (shouldUpgrade != true || !context.mounted) {
      return;
    }

    await ref.read(workLogActionsProvider).enablePremium();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('プレミアムを有効にしました')),
      );
  }

  Future<void> _showCloudPromo(BuildContext context) async {
    final wantsPremium = await showCloudPromoSheet(context);
    if (wantsPremium == true && context.mounted) {
      await _showPremiumOffer(context);
    }
  }

  Future<void> _applyClientBulk(
    BuildContext context,
    List<Client> clients,
    List<int> ids,
  ) async {
    final clientId = await showClientPickerSheet(
      context: context,
      clients: clients,
      onCreate: (name) => ref.read(workLogActionsProvider).createClient(name),
    );
    if (clientId == null) {
      return;
    }

    setState(() => _isApplyingBulk = true);
    await ref
        .read(workLogActionsProvider)
        .applyClientToSelected(ids: ids, clientId: clientId);
    ref.read(selectedWorkLogIdsProvider.notifier).state = <int>{};
    setState(() => _isApplyingBulk = false);
  }

  Future<void> _applyPropertyBulk(
    BuildContext context,
    List<Property> properties,
    List<Client> clients,
    List<int> ids,
  ) async {
    final propertyId = await showPropertyPickerSheet(
      context: context,
      properties: properties,
      clients: clients,
      onCreate: (name, clientId) {
        return ref.read(workLogActionsProvider).createProperty(
              name: name,
              clientId: clientId,
            );
      },
    );
    if (propertyId == null) {
      return;
    }

    setState(() => _isApplyingBulk = true);
    await ref
        .read(workLogActionsProvider)
        .applyPropertyToSelected(ids: ids, propertyId: propertyId);
    ref.read(selectedWorkLogIdsProvider.notifier).state = <int>{};
    setState(() => _isApplyingBulk = false);
  }

  Future<void> _markSelectedCompleted(List<int> ids) async {
    setState(() => _isApplyingBulk = true);
    await ref.read(workLogActionsProvider).markSelectedCompleted(ids);
    ref.read(selectedWorkLogIdsProvider.notifier).state = <int>{};
    setState(() => _isApplyingBulk = false);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final WorkLogStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == WorkLogStatus.unsorted
        ? Colors.orange.shade100
        : Colors.green.shade100;

    return Chip(
      backgroundColor: color,
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
    );
  }
}
