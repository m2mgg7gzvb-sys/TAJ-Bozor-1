import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notify_store.dart';
import 'theme.dart';
import 'user_profile_screen.dart';

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

  /// Профили собеседников (имя и фото) для аватаров у сообщений.
  final Map<String, Map<String, dynamic>> _profiles = {};
  final Set<String> _requested = {};

  void _requestProfiles(List<Map<String, dynamic>> items) {
    final missing = <String>{
      for (final m in items)
        if (m['sender_id'] is String && m['sender_id'] != _me) m['sender_id'] as String,
    }.where((id) => !_requested.contains(id)).toList();
    if (missing.isEmpty) return;
    _requested.addAll(missing);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfiles(missing));
  }

  Future<void> _loadProfiles(List<String> ids) async {
    try {
      final rows = List<Map<String, dynamic>>.from(await Supabase.instance.client
          .from('profiles')
          .select('id, name, avatar_url')
          .inFilter('id', ids));
      if (!mounted) return;
      setState(() {
        for (final r in rows) {
          _profiles[r['id'] as String] = r;
        }
      });
    } catch (_) {
      // Без имени и фото сообщения всё равно показываются
    }
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

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
                _requestProfiles(items);
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
                    final senderId = m['sender_id'] as String?;
                    final prof = senderId == null ? null : _profiles[senderId];
                    final name = (prof?['name'] as String?)?.trim();
                    final bubble = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        m['body'] as String,
                        style: TextStyle(color: mine ? Colors.white : AppColors.ink, height: 1.3),
                      ),
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!mine)
                            GestureDetector(
                              onTap: senderId == null ? null : () => _openProfile(senderId),
                              child: UserAvatar(
                                name: (name == null || name.isEmpty) ? 'П' : name,
                                url: prof?['avatar_url'] as String?,
                                radius: 16,
                              ),
                            ),
                          if (!mine) const SizedBox(width: 8),
                          Flexible(child: bubble),
                        ],
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
