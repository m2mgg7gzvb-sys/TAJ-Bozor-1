import 'package:flutter/material.dart';

import 'glass_widgets.dart';
import 'theme.dart';

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
    return GlassDialog(
      title: 'Удалить объявление?',
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
            decoration: InputDecoration(
            hintText: 'Delete',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: AppColors.ruby,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
