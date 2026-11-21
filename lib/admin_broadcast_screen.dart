import 'lang_store.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'green_button.dart';

/// Рассылка всем пользователям: каждому приходит уведомление (и пуш).
class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (title.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Введите заголовок', 'Сарлавҳаро ворид кунед'))));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Отправить всем?', 'Ба ҳама фиристем?')),
        content: Text(tr('«$title» получат все пользователи. Отменить будет нельзя.', '«$title» ба ҳамаи корбарон мерасад. Бекор кардан мумкин нест.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Отмена', 'Бекор'))),
          GreenButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Отправить', 'Фиристодан'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final n = await Supabase.instance.client
          .rpc('admin_broadcast', params: {'p_title': title, 'p_body': body});
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(tr('Отправлено: $n', 'Фиристода шуд: $n'))));
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(tr('Не удалось отправить рассылку', 'Фиристодани паёми умумӣ муяссар нашуд'))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),
        title: Text(tr('Рассылка', 'Паёми умумӣ')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: tr('Заголовок', 'Сарлавҳа'),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            minLines: 4,
            maxLines: 8,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: tr('Текст', 'Матн'),
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('Уведомление получат все пользователи приложения.', 'Огоҳиномаро ҳамаи корбарони барнома мегиранд.'),
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GreenButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.campaign_rounded),
            label: Text(tr('Отправить всем', 'Ба ҳама фиристодан')),
          ),
        ],
      ),
    );
  }
}
