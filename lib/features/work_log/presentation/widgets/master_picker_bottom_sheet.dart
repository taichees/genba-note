import 'package:flutter/material.dart';

import '../../../master/domain/client.dart';
import '../../../master/domain/property.dart';

typedef ClientCreateCallback = Future<int> Function(String name);
typedef PropertyCreateCallback = Future<int> Function(String name, int? clientId);

const int unsetSelectionId = -1;

Future<int?> showClientPickerSheet({
  required BuildContext context,
  required List<Client> clients,
  required ClientCreateCallback onCreate,
  bool includeUnset = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            if (includeUnset)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('未設定にする'),
                onTap: () => Navigator.of(context).pop(unsetSelectionId),
              ),
            for (final client in clients)
              ListTile(
                title: Text(client.name),
                onTap: () => Navigator.of(context).pop(client.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('＋新規追加'),
              onTap: () async {
                final createdId = await showDialog<int>(
                  context: context,
                  builder: (_) => _CreateClientDialog(onCreate: onCreate),
                );
                if (context.mounted) {
                  Navigator.of(context).pop(createdId);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<int?> showPropertyPickerSheet({
  required BuildContext context,
  required List<Property> properties,
  required List<Client> clients,
  required PropertyCreateCallback onCreate,
  bool includeUnset = false,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            if (includeUnset)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('未設定にする'),
                onTap: () => Navigator.of(context).pop(unsetSelectionId),
              ),
            for (final property in properties)
              ListTile(
                title: Text(property.name),
                onTap: () => Navigator.of(context).pop(property.id),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('＋新規追加'),
              onTap: () async {
                final createdId = await showDialog<int>(
                  context: context,
                  builder: (_) => _CreatePropertyDialog(
                    clients: clients,
                    onCreate: onCreate,
                  ),
                );
                if (context.mounted) {
                  Navigator.of(context).pop(createdId);
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

class _CreateClientDialog extends StatefulWidget {
  const _CreateClientDialog({required this.onCreate});

  final ClientCreateCallback onCreate;

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    final id = await widget.onCreate(name);
    if (mounted) {
      Navigator.of(context).pop(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('請求先を追加'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '請求先名'),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('追加'),
        ),
      ],
    );
  }
}

class _CreatePropertyDialog extends StatefulWidget {
  const _CreatePropertyDialog({
    required this.clients,
    required this.onCreate,
  });

  final List<Client> clients;
  final PropertyCreateCallback onCreate;

  @override
  State<_CreatePropertyDialog> createState() => _CreatePropertyDialogState();
}

class _CreatePropertyDialogState extends State<_CreatePropertyDialog> {
  final TextEditingController _nameController = TextEditingController();
  int? _selectedClientId;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    final id = await widget.onCreate(name, _selectedClientId);
    if (mounted) {
      Navigator.of(context).pop(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('物件を追加'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: '物件名'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            initialValue: _selectedClientId,
            decoration: const InputDecoration(labelText: '請求先'),
            items: <DropdownMenuItem<int?>>[
              const DropdownMenuItem<int?>(value: null, child: Text('未設定')),
              ...widget.clients.map(
                (client) => DropdownMenuItem<int?>(
                  value: client.id,
                  child: Text(client.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedClientId = value),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('追加'),
        ),
      ],
    );
  }
}
