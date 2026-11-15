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
      messenger.showSnackBar(const SnackBar(content: Text('Введите заголовок')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отправить всем?'),
        content: Text('«$title» получат все пользователи. Отменить будет нельзя.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          GreenButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отправить')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sending = true);
    try {
      final n = await Supabase.instance.client
          .rpc('admin_broadcast', params: {'p_title': title, 'p_body': body});
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Отправлено: $n')));
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text('Не удалось отправить рассылку')));
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
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.deep),
        title: const Text('Рассылка'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: 'Заголовок',
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
              labelText: 'Текст',
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Уведомление получат все пользователи приложения.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GreenButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.campaign_rounded),
            label: const Text('Отправить всем'),
          ),
        ],
      ),
    );
  }
}
