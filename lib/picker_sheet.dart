import 'package:flutter/material.dart';

import 'theme.dart';

/// Нижнее окно выбора из списка с поиском сверху (марка, модель и т.п.).
/// anyLabel — строка «Все …» первой в списке; если null, её не показываем.
class PickerSheet extends StatefulWidget {
  const PickerSheet({
    required this.title,
    required this.items,
    this.anyLabel,
    this.current,
    this.popular = const [],
  });

  final String title;
  final List<String> items;
  final String? anyLabel;
  final String? current;
  final List<String> popular;

  @override
  State<PickerSheet> createState() => PickerSheetState();
}

class PickerSheetState extends State<PickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted),
      ),
    );
  }

  Widget _row(String text, {required bool selected, required VoidCallback onTap}) {
    return Material(
      color: selected ? AppColors.mint : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.primary : AppColors.ink,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.items
        : widget.items.where((i) => i.toLowerCase().contains(q)).toList();
    final popularShown = [
      for (final m in widget.popular)
        if (widget.items.contains(m)) m,
    ];
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEDC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${widget.items.length}',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (widget.items.length > 8)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.onLight),
                  decoration: InputDecoration(
                    hintText: 'Поиск',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: AppColors.lightFill,
                    hintStyle: const TextStyle(color: AppColors.hintOnLight),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                children: [
                  if (widget.anyLabel != null)
                    _row(
                      widget.anyLabel!,
                      selected: widget.current == null,
                      onTap: () => Navigator.pop(context, ''),
                    ),
                  if (q.isEmpty && popularShown.isNotEmpty) ...[
                    _sectionTitle('Популярные'),
                    for (final i in popularShown)
                      _row(
                        i,
                        selected: i == widget.current,
                        onTap: () => Navigator.pop(context, i),
                      ),
                    _sectionTitle('Все'),
                    for (final i in shown.where((i) => !popularShown.contains(i)))
                      _row(
                        i,
                        selected: i == widget.current,
                        onTap: () => Navigator.pop(context, i),
                      ),
                  ] else
                    for (final i in shown)
                      _row(
                        i,
                        selected: i == widget.current,
                        onTap: () => Navigator.pop(context, i),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

