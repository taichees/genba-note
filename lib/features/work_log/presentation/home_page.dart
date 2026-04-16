import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_time_label.dart';
import '../../../shared/providers/app_providers.dart';
import '../../master/domain/client.dart';
import '../../master/domain/property.dart';
import '../domain/work_log_filter.dart';
import '../domain/work_log_status.dart';
import 'widgets/master_picker_bottom_sheet.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isRecording = false;
  bool _isApplyingBulk = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(workLogActionsProvider).prepareLocationPermission();
    });
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
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
    final selectedIds = ref.watch(selectedWorkLogIdsProvider);
    final clients = ref.watch(clientsProvider).valueOrNull ?? const <Client>[];
    final properties =
        ref.watch(propertiesProvider).valueOrNull ?? const <Property>[];
    final selectionMode = _tabController.index == 1 && selectedIds.isNotEmpty;

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
    await ref.read(workLogActionsProvider).quickRecord();
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
