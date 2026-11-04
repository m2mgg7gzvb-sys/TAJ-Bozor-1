import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notify_store.dart';
import 'theme.dart';

/// Находит переписку текущего пользователя или создаёт новую.
/// kind: 'support' (чат с командой) или 'listing' (чат по объявлению).
Future<String> findOrCreateConversation({required String kind, String? listingId, String? sellerId}) async {
  final db = Supabase.instance.client;
  final me = db.auth.currentUser!.id;

  var query = db.from('conversations').select('id').eq('kind', kind).eq('buyer_id', me);
  if (listingId != null) query = query.eq('listing_id', listingId);
  if (sellerId != null) query = query.eq('seller_id', sellerId);

  final found = await query.limit(1);
  if (found.isNotEmpty) return found.first['id'] as String;

  final created = await db
      .from('conversations')
      .insert({
        'kind': kind,
        'listing_id': listingId,
        'buyer_id': me,
        'seller_id': sellerId,
      })
      .select('id')
      .single();
  return created['id'] as String;
}

/// Экран переписки: сообщения в реальном времени и поле ввода.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.staffTicket = false,
    this.canFinish = true,
  });

  final String conversationId;
  final String title;

  /// Обращение в поддержку, открытое сотрудником: показываем кнопки статуса.
  final bool staffTicket;

  /// Может ли сотрудник завершить обращение (красный статус) — только главный админ.
  final bool canFinish;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  late final Stream<List<Map<String, dynamic>>> _stream = Supabase.instance.client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', widget.conversationId);

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    markChatRead(widget.conversationId);
  }

  @override
  void dispose() {
    markChatRead(widget.conversationId);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _me,
        'body': text,
      });
      _ctrl.clear();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить сообщение')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _setTicket(String status) async {
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({'status': status})
          .eq('id', widget.conversationId);
      if (!mounted) return;
      if (status == 'answered') {
        // Завершённое обращение скрывается из списка для сотрудников — возвращаемся назад
        Navigator.of(context).pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Обращение: на помощи')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить статус')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          if (widget.staffTicket)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _setTicket('in_progress'),
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('На помощь'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9A7400),
                        side: const BorderSide(color: Color(0xFFF2B600), width: 1.5),
                      ),
                    ),
                  ),
                  if (widget.canFinish) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _setTicket('answered'),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Завершить'),
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Не удалось загрузить переписку'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = [...snap.data!]
                  ..sort((a, b) => (a['created_at'] as String).compareTo(b['created_at'] as String));
                if (items.isEmpty) {
                  return const Center(
                    child: Text('Напишите первое сообщение', style: TextStyle(color: AppColors.muted)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final m = items[items.length - 1 - i];
                    final mine = m['sender_id'] == _me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(
                          color: mine ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          m['body'] as String,
                          style: TextStyle(color: mine ? Colors.white : AppColors.ink, height: 1.3),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Сообщение',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
