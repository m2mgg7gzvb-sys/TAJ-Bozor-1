import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_log.dart';
import 'confirm_delete.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'theme.dart';

const _statusNames = <String, String>{
  'active': 'Активно',
  'moderation': 'На проверке',
  'frozen': 'Заморожено',
  'blocked': 'Заблокировано',
  'hidden': 'Скрыто',
  'expired': 'Срок истёк',
  'sold': 'Продано',
};

String _shortDate(String? raw) => (raw ?? '').replaceFirst('T', ' ').split('.').first;

/// Переписка по одному объявлению: все решения и сообщения администратора,
/// а также действия с объявлением внизу экрана.
class AdminThreadScreen extends StatefulWidget {
  const AdminThreadScreen({super.key, required this.listingId});

  final String listingId;

  @override
  State<AdminThreadScreen> createState() => _AdminThreadScreenState();
}

class _Thread {
  const _Thread(this.listing, this.logs);
  final Map<String, dynamic>? listing;
  final List<Map<String, dynamic>> logs;
}

class _AdminThreadScreenState extends State<AdminThreadScreen> {
  final _db = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  late Future<_Thread> _future = _load();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  /// Открывает объявление так, как его видит покупатель. Управление остаётся на этом экране.
  Future<void> _openListing() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final row = await _db.from('listings').select('$listingSelect, status').eq('id', widget.listingId).single();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ListingDetailScreen(item: Map<String, dynamic>.from(row))),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть объявление')));
    }
  }

  Future<_Thread> _load() async {
    final listing = await _db
        .from('listings')
        .select('id, title, status, price, currency, city, admin_note, public_id')
        .eq('id', widget.listingId)
        .maybeSingle();
    final logs = await _db
        .from('admin_log')
        .select('action, note, created_at')
        .eq('listing_id', widget.listingId)
        .order('created_at', ascending: true);
    return _Thread(listing, List<Map<String, dynamic>>.from(logs));
  }

  void _reload() => setState(() => _future = _load());

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Меняет статус от имени администратора: с причиной, с подтверждением удаления или без.
  Future<void> _act({
    required String status,
    required String action,
    required String done,
    String? question,
    bool confirmDelete = false,
  }) async {
    String? note;
    if (confirmDelete) {
      if (!await confirmDeleteByTyping(context)) return;
    } else if (question != null) {
      final text = await askReason(context, question);
      if (text == null) return;
      note = text.isEmpty ? null : text;
    }
    try {
      await adminSetStatus(listingId: widget.listingId, status: status, action: action, note: note);
      _reload();
      _snack(done);
    } catch (_) {
      _snack('Не удалось сохранить изменение');
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await adminSendMessage(widget.listingId, text);
      _msgCtrl.clear();
      _reload();
      _snack('Сообщение отправлено владельцу');
    } catch (_) {
      _snack('Не удалось отправить сообщение');
    }
  }

  List<Widget> _actionButtons(String status) {
    Widget btn(String label, VoidCallback onTap, {bool filled = false, bool danger = false}) {
      if (danger) {
        return TextButton(
          onPressed: onTap,
          child: Text(label, style: TextStyle(color: Colors.red.shade700)),
        );
      }
      return filled
          ? FilledButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label));
    }

    final freeze = btn(
      'Заморозить',
      () => _act(status: 'frozen', action: 'freeze', done: 'Объявление заморожено', question: 'Заморозить объявление?'),
    );
    final block = btn(
      'Заблокировать',
      () => _act(status: 'blocked', action: 'block', done: 'Объявление заблокировано', question: 'Заблокировать объявление?'),
    );
    final remove = btn(
      'Удалить',
      () => _act(status: 'hidden', action: 'delete', done: 'Объявление удалено', confirmDelete: true),
      danger: true,
    );

    return switch (status) {
      'active' => [freeze, block, remove],
      'frozen' => [
          btn('Разморозить',
              () => _act(status: 'active', action: 'unfreeze', done: 'Объявление разморожено'),
              filled: true),
          block,
          remove,
        ],
      'blocked' => [
          btn('Разблокировать',
              () => _act(status: 'active', action: 'unblock', done: 'Объявление разблокировано'),
              filled: true),
          remove,
        ],
      'moderation' => [
          btn('Опубликовать',
              () => _act(status: 'active', action: 'approve', done: 'Объявление опубликовано'),
              filled: true),
          block,
        ],
      'hidden' => [
          btn('Вернуть в активные',
              () => _act(status: 'active', action: 'restore', done: 'Объявление возвращено'),
              filled: true),
        ],
      _ => [block],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Объявление'),
        actions: [
          IconButton(
            tooltip: 'Открыть объявление',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openListing,
          ),
        ],
      ),
      body: FutureBuilder<_Thread>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return const Center(child: Text('Не удалось загрузить переписку'));
          }
          final data = snap.data!;
          final listing = data.listing;
          final status = (listing?['status'] as String?) ?? '';
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(radius: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing == null ? 'Объявление не найдено' : ((listing['title'] as String?) ?? ''),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          if (listing != null) ...[
                            const SizedBox(height: 4),
                            Text(priceText(listing),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                            Text('Статус: ${_statusNames[status] ?? status}',
                                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          Text('ID: ${listing?['public_id'] ?? '—'}',
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (data.logs.isEmpty)
                      const Text('Записей пока нет', style: TextStyle(color: AppColors.muted)),
                    for (final e in data.logs) ...[
                      _Bubble(
                        action: (e['action'] as String?) ?? '',
                        note: e['note'] as String?,
                        date: _shortDate(e['created_at'] as String?),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              if (listing != null)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(spacing: 8, runSpacing: 8, children: _actionButtons(status)),
                ),
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Написать владельцу от имени администратора',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF1F4F3),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Отправить',
                      onPressed: _send,
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.action, required this.note, required this.date});

  final String action;
  final String? note;
  final String date;

  @override
  Widget build(BuildContext context) {
    final isMessage = action == 'message';
    final hasNote = note != null && note!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMessage ? AppColors.mint : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              const Text('Администратор',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(adminActionNames[action] ?? action, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hasNote) ...[
            const SizedBox(height: 2),
            Text(isMessage ? note! : 'Причина: $note', style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 4),
          Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Поиск объявления по ID для админа: открывает управление объявлением.
class AdminChatsScreen extends StatefulWidget {
  const AdminChatsScreen({super.key});

  @override
  State<AdminChatsScreen> createState() => _AdminChatsScreenState();
}

class _AdminChatsScreenState extends State<AdminChatsScreen> {
  final _db = Supabase.instance.client;
  final _idCtrl = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _idCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final id = _idCtrl.text.trim();
    if (id.isEmpty || _searching) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _searching = true);
    try {
      final code = id.toUpperCase();
      final row = code.startsWith('OB-')
          ? await _db.from('listings').select('id').eq('public_id', code).maybeSingle()
          : await _db.from('listings').select('id').eq('id', id).maybeSingle();
      if (!mounted) return;
      if (row == null) {
        messenger.showSnackBar(const SnackBar(content: Text('Объявление с таким ID не найдено')));
        return;
      }
      final uuid = row['id'] as String;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminThreadScreen(listingId: uuid)),
      );
      _idCtrl.clear();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Проверьте ID объявления')));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск объявления')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _idCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    hintText: 'Например OB-1A2B3C4D',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFE6ECEA),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: const Text('Найти объявление'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined, size: 72, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Поиск по ID',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Введите ID объявления, чтобы открыть его\nи управлять им',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
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
