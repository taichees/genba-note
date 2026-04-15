import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/date_time_label.dart';
import '../../../../shared/providers/app_providers.dart';
import '../../../master/domain/client.dart';
import '../../../master/domain/property.dart';
import '../../domain/work_log_status.dart';
import '../widgets/master_picker_bottom_sheet.dart';

class WorkLogDetailPage extends ConsumerStatefulWidget {
  const WorkLogDetailPage({super.key, required this.workLogId});

  final int workLogId;

  @override
  ConsumerState<WorkLogDetailPage> createState() => _WorkLogDetailPageState();
}

class _WorkLogDetailPageState extends ConsumerState<WorkLogDetailPage> {
  final TextEditingController _memoController = TextEditingController();
  int? _selectedPropertyId;
  int? _selectedClientId;
  WorkLogStatus _status = WorkLogStatus.unsorted;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailState = ref.watch(workLogDetailProvider(widget.workLogId));
    final clientsState = ref.watch(clientsProvider);
    final propertiesState = ref.watch(propertiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('詳細編集')),
      body: detailState.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('記録が見つかりません'));
          }

          if (!_initialized) {
            _selectedPropertyId = detail.workLog.propertyId;
            _selectedClientId = detail.workLog.clientId;
            _memoController.text = detail.workLog.memo ?? '';
            _status = detail.workLog.status;
            _initialized = true;
          }

          final clients = clientsState.valueOrNull ?? const <Client>[];
          final properties = propertiesState.valueOrNull ?? const <Property>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('作業日時'),
                  subtitle: Text(detail.workLog.datetime.toShortLabel()),
                ),
              ),
              const SizedBox(height: 12),
              _SelectionField(
                label: '物件',
                value: _propertyLabel(properties),
                onTap: () async {
                  final selectedId = await showPropertyPickerSheet(
                    context: context,
                    properties: properties,
                    clients: clients,
                    includeUnset: true,
                    onCreate: (name, clientId) async {
                      return ref.read(workLogActionsProvider).createProperty(
                            name: name,
                            clientId: clientId,
                          );
                    },
                  );
                  if (mounted && selectedId != null) {
                    setState(() {
                      _selectedPropertyId =
                          selectedId == unsetSelectionId ? null : selectedId;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              _SelectionField(
                label: '請求先',
                value: _clientLabel(clients),
                onTap: () async {
                  final selectedId = await showClientPickerSheet(
                    context: context,
                    clients: clients,
                    includeUnset: true,
                    onCreate: (name) async {
                      return ref.read(workLogActionsProvider).createClient(name);
                    },
                  );
                  if (mounted && selectedId != null) {
                    setState(() {
                      _selectedClientId =
                          selectedId == unsetSelectionId ? null : selectedId;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _memoController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'メモ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WorkLogStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'ステータス',
                  border: OutlineInputBorder(),
                ),
                items: WorkLogStatus.values
                    .map(
                      (status) => DropdownMenuItem<WorkLogStatus>(
                        value: status,
                        child: Text(status.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => _save(
                          workLogId: detail.workLog.id,
                        ),
                icon: const Icon(Icons.save),
                label: const Text('保存'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('読込に失敗しました: $error')),
      ),
    );
  }

  String _propertyLabel(List<Property> properties) {
    Property? property;
    for (final item in properties) {
      if (item.id == _selectedPropertyId) {
        property = item;
        break;
      }
    }
    return property?.name ?? AppStrings.unassigned;
  }

  String _clientLabel(List<Client> clients) {
    Client? client;
    for (final item in clients) {
      if (item.id == _selectedClientId) {
        client = item;
        break;
      }
    }
    return client?.name ?? AppStrings.unassigned;
  }

  Future<void> _save({required int workLogId}) async {
    setState(() => _isSaving = true);
    await ref.read(workLogActionsProvider).saveWorkLog(
          id: workLogId,
          propertyId: _selectedPropertyId,
          clientId: _selectedClientId,
          memo: _memoController.text,
          status: _status,
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _SelectionField extends StatelessWidget {
  const _SelectionField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.edit),
        ),
        child: Text(value),
      ),
    );
  }
}
