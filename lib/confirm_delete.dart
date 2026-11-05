import 'package:flutter/material.dart';

/// Окно удаления: кнопка «Удалить» активна только после того, как пользователь напишет Delete.
Future<bool> confirmDeleteByTyping(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => const _DeleteDialog(),
  );
  return ok == true;
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ctrl.text.trim() == 'Delete';
    return AlertDialog(
      title: const Text('Удалить объявление?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Если хотите удалить объявление, напишите Delete'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Delete', border: OutlineInputBorder()),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('Удалить'),
        ),
      ],
    );
  }
}
