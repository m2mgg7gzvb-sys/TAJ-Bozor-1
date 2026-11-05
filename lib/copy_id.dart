import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Строка с ID и кнопкой «копировать». Текст не выделяется, поэтому не появляются синие ручки выделения.
class CopyIdLine extends StatelessWidget {
  const CopyIdLine({super.key, required this.label, required this.id, this.suffix = '', this.style});

  final String label;
  final String id;
  final String suffix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final textStyle = style ?? const TextStyle(color: AppColors.muted, fontSize: 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text('$label $id$suffix', style: textStyle)),
        const SizedBox(width: 4),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: id));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ID скопирован'), duration: Duration(seconds: 2)),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.copy_rounded, size: 14, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}
