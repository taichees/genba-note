import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_time_label.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../domain/work_log_filter.dart';
import '../../domain/work_log_list_item.dart';
import '../../domain/work_log_status.dart';

class WorkLogMapPage extends ConsumerStatefulWidget {
  const WorkLogMapPage({
    super.key,
    this.selectedWorkLogId,
  });

  final int? selectedWorkLogId;

  @override
  ConsumerState<WorkLogMapPage> createState() => _WorkLogMapPageState();
}

class _WorkLogMapPageState extends ConsumerState<WorkLogMapPage> {
  final MapController _mapController = MapController();
  WorkLogFilter _filter = WorkLogFilter.all;
  int? _selectedWorkLogId;
  bool _didApplyInitialSelection = false;
  bool _isMapReady = false;

  @override
  Widget build(BuildContext context) {
    final centerState = ref.watch(mapInitialCenterProvider);
    final logsState = ref.watch(workLogListByFilterProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('地図'),
      ),
      body: centerState.when(
        data: (center) {
          return logsState.when(
            data: (items) {
              final gpsItems = items
                  .where((item) => item.latitude != null && item.longitude != null)
                  .toList();
              _applyInitialSelectionIfNeeded(gpsItems);

              return Stack(
                children: <Widget>[
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 15,
                      onMapReady: () {
                        _isMapReady = true;
                        _applyInitialSelectionIfNeeded(gpsItems);
                      },
                      onTap: (tapPosition, point) {
                        if (_selectedWorkLogId != null) {
                          setState(() => _selectedWorkLogId = null);
                        }
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'jp.genbanote.app',
                      ),
                      MarkerLayer(
                        markers: gpsItems.map(_buildMarker).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 84,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SegmentedButton<WorkLogFilter>(
                        segments: const <ButtonSegment<WorkLogFilter>>[
                          ButtonSegment<WorkLogFilter>(
                            value: WorkLogFilter.all,
                            label: Text('すべて'),
                          ),
                          ButtonSegment<WorkLogFilter>(
                            value: WorkLogFilter.unsorted,
                            label: Text('未整理のみ'),
                          ),
                        ],
                        selected: <WorkLogFilter>{_filter},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _filter = selection.first;
                            _selectedWorkLogId = null;
                          });
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'current-location',
                      onPressed: () => _moveToCurrentLocation(),
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  DraggableScrollableSheet(
                    initialChildSize: 0.24,
                    minChildSize: 0.16,
                    maxChildSize: 0.52,
                    builder: (context, scrollController) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              blurRadius: 12,
                              color: Colors.black12,
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[
                            const SizedBox(height: 8),
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                children: <Widget>[
                                  Text(
                                    _filter == WorkLogFilter.all
                                        ? '履歴一覧'
                                        : '未整理一覧',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  Text('${items.length}件'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: items.isEmpty
                                  ? const Center(child: Text('表示できる履歴がありません'))
                                  : ListView.separated(
                                      controller: scrollController,
                                      itemCount: items.length,
                                      separatorBuilder: (context, index) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final item = items[index];
                                        final selected =
                                            _selectedWorkLogId == item.id;
                                        return ListTile(
                                          selected: selected,
                                          title: Text(item.datetime.toShortLabel()),
                                          subtitle: Text(
                                            item.propertyName ??
                                                AppStrings.unassigned,
                                          ),
                                          trailing: _MapStatusChip(
                                            status: item.status,
                                            selected: selected,
                                          ),
                                          onTap: item.latitude == null ||
                                                  item.longitude == null
                                              ? null
                                              : () => _selectFromList(item),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('地図データの読込に失敗しました: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('現在地の取得に失敗しました: $error')),
      ),
    );
  }

  Marker _buildMarker(WorkLogListItem item) {
    final selected = _selectedWorkLogId == item.id;
    final markerColor = selected
        ? Colors.red
        : item.status == WorkLogStatus.completed
            ? Colors.blue
            : Colors.grey;

    return Marker(
      point: LatLng(item.latitude!, item.longitude!),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _selectMarker(item),
        child: Icon(
          Icons.location_on,
          color: markerColor,
          size: 40,
        ),
      ),
    );
  }

  Future<void> _selectMarker(WorkLogListItem item) async {
    setState(() => _selectedWorkLogId = item.id);
    _mapController.move(LatLng(item.latitude!, item.longitude!), _mapController.camera.zoom);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.datetime.toShortLabel(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _ModalRow(
                  label: '物件',
                  value: item.propertyName ?? AppStrings.unassigned,
                ),
                const SizedBox(height: 8),
                _ModalRow(
                  label: '請求先',
                  value: item.clientName ?? AppStrings.unassigned,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    this.context.push('/work-logs/${item.id}');
                  },
                  child: const Text('詳細を見る'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _moveToCurrentLocation() async {
    final center = await ref.read(mapInitialCenterProvider.future);
    _mapController.move(center, 15);
  }

  void _selectFromList(WorkLogListItem item) {
    setState(() => _selectedWorkLogId = item.id);
    _mapController.move(LatLng(item.latitude!, item.longitude!), 17);
  }

  void _applyInitialSelectionIfNeeded(List<WorkLogListItem> items) {
    if (_didApplyInitialSelection ||
        !_isMapReady ||
        widget.selectedWorkLogId == null) {
      return;
    }

    final targetId = widget.selectedWorkLogId!;
    WorkLogListItem? target;
    for (final item in items) {
      if (item.id == targetId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      _didApplyInitialSelection = true;
      return;
    }
    final initialTarget = target;

    _didApplyInitialSelection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) {
        return;
      }
      setState(() => _selectedWorkLogId = initialTarget.id);
      _mapController.move(
        LatLng(initialTarget.latitude!, initialTarget.longitude!),
        17,
      );
    });
  }
}

class _MapStatusChip extends StatelessWidget {
  const _MapStatusChip({
    required this.status,
    required this.selected,
  });

  final WorkLogStatus status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected
        ? Colors.red.shade100
        : status == WorkLogStatus.completed
            ? Colors.blue.shade100
            : Colors.grey.shade300;

    return Chip(
      backgroundColor: backgroundColor,
      label: Text(status.label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ModalRow extends StatelessWidget {
  const _ModalRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 56,
          child: Text(label),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
