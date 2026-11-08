import 'package:flutter/material.dart';

import 'lang_store.dart';

/// Окно выбора способа звонка: через Интернет или обычный телефонный звонок.
Future<void> showCallOptionsSheet(
  BuildContext context, {
  required VoidCallback onInternet,
  required VoidCallback onDirect,
}) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('Как позвонить?', 'Чӣ тавр занг занем?'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2D8CFF),
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.wifi_calling_3_rounded),
              label: Text(tr('Через Интернет', 'Тавассути Интернет')),
              onPressed: () {
                Navigator.pop(ctx);
                onInternet();
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF13C15A),
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.phone_rounded),
              label: Text(tr('Прямой звонок', 'Занги мустақим')),
              onPressed: () {
                Navigator.pop(ctx);
                onDirect();
              },
            ),
          ],
        ),
      ),
    ),
  );
}
