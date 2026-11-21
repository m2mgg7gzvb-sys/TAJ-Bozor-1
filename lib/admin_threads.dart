import 'lang_store.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_log.dart';
import 'create_listing_screen.dart';
import 'confirm_delete.dart';
import 'listing_detail_screen.dart';
import 'listing_utils.dart';
import 'user_profile_screen.dart';
import 'glass_widgets.dart';
import 'theme.dart';
import 'green_button.dart';

final _statusNames = <String, String>{
  'active': tr('Активно', 'Фаъол'),
  'moderation': tr('На проверке', 'Санҷиш дар ҷараён'),
  'frozen': tr('Заморожено', 'Музд шудааст'),
  'blocked': tr('Заблокировано', 'Маҳдуд шудааст'),
  'hidden': tr('Скрыто', 'Пинҳон'),
  'expired': tr('Срок истёк', 'Мӯҳлат гузашт'),
  'sold': tr('Продано', 'Фурӯхта шуд'),
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
      messenger.showSnackBar(SnackBar(content: Text(tr('Не удалось открыть объявление', 'Кушодани эълон муяссар нашуд'))));
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

  /// Правка текста и характеристик объявления админом (статус и профиль владельца не трогаем).
  Future<void> _editListing() async {
    try {
      final row = await _db.from('listings').select('$listingSelect, status').eq('id', widget.listingId).single();
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CreateListingScreen(listing: Map<String, dynamic>.from(row), adminEdit: true),
        ),
      );
      if (saved == true) {
        _reload();
        _snack(tr('Объявление изменено', 'Эълон тағйир ёфт'));
      }
    } catch (_) {
      _snack(tr('Не удалось открыть объявление для правки', 'Барои таҳрир кушодани эълон муяссар нашуд'));
    }
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
      _snack(tr('Не удалось сохранить изменение', 'Захира кардани тағйирот муяссар нашуд'));
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await adminSendMessage(widget.listingId, text);
      _msgCtrl.clear();
      _reload();
      _snack(tr('Сообщение отправлено владельцу', 'Паём ба соҳиб фиристода шуд'));
    } catch (_) {
      _snack(tr('Не удалось отправить сообщение', 'Фиристодани паём муяссар нашуд'));
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
          ? GreenButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label));
    }

    final freeze = btn(
      tr('Заморозить', 'Музд кардан'),
      () => _act(status: 'frozen', action: 'freeze', done: tr('Объявление заморожено', 'Эълон музд карда шуд'), question: tr('Заморозить объявление?', 'Эълонро музд кунем?')),
    );
    final block = btn(
      tr('Заблокировать', 'Маҳдуд кардан'),
      () => _act(status: 'blocked', action: 'block', done: tr('Объявление заблокировано', 'Эълон маҳдуд карда шуд'), question: tr('Заблокировать объявление?', 'Эълонро маҳдуд кунем?')),
    );
    final remove = btn(
      tr('Удалить', 'Нест кардан'),
      () => _act(status: 'hidden', action: 'delete', done: tr('Объявление удалено', 'Эълон нест карда шуд'), confirmDelete: true),
      danger: true,
    );

    return switch (status) {
      'active' => [freeze, block, remove],
      'frozen' => [
          btn(tr('Разморозить', 'Аз музд баровардан'),
              () => _act(status: 'active', action: 'unfreeze', done: tr('Объявление разморожено', 'Эълон аз музд баромад')),
              filled: true),
          block,
          remove,
        ],
      'blocked' => [
          btn(tr('Разблокировать', 'Маҳдудиятро бардоштан'),
              () => _act(status: 'active', action: 'unblock', done: tr('Объявление разблокировано', 'Эълон аз маҳдудият баромад')),
              filled: true),
          remove,
        ],
      'moderation' => [
          btn(tr('Опубликовать', 'Нашр кардан'),
              () => _act(status: 'active', action: 'approve', done: tr('Объявление опубликовано', 'Эълон нашр шуд')),
              filled: true),
          block,
        ],
      'hidden' => [
          btn(tr('Вернуть в активные', 'Ба фаъолон баргардонидан'),
              () => _act(status: 'active', action: 'restore', done: tr('Объявление возвращено', 'Эълон ба фаъолон баргардонида шуд')),
              filled: true),
        ],
      _ => [block],
    };
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
        title: Text(tr('Объявление', 'Эълон')),
        actions: [
          IconButton(
            tooltip: tr('Открыть объявление', 'Кушодани эълон'),
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
            return Center(child: Text(tr('Не удалось загрузить переписку', 'Бор кардани мукотибот муяссар нашуд')));
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
                      decoration: glowDecoration(radius: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            listing == null ? tr('Объявление не найдено', 'Эълон ёфт нашуд') : ((listing['title'] as String?) ?? ''),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          if (listing != null) ...[
                            const SizedBox(height: 4),
                            Text(priceText(listing),
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                            Text(tr('Статус: ${_statusNames[status] ?? status}', 'Ҳолат: ${_statusNames[status] ?? status}'),
                                style: TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                          const SizedBox(height: 6),
                          Text('ID: ${listing?['public_id'] ?? '—'}',
                              style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (data.logs.isEmpty)
                      Text(tr('Записей пока нет', 'Ҳоло сабт нест'), style: TextStyle(color: AppColors.muted)),
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
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton(onPressed: _editListing, child: Text(tr('Изменить', 'Таҳрир'))),
                    ..._actionButtons(status),
                  ]),
                ),
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgCtrl,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: tr('Написать владельцу от имени администратора', 'Аз номи администратор ба соҳиб нависед'),
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: tr('Отправить', 'Фиристодан'),
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
        color: isMessage ? AppColors.mint : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(tr('Администратор', 'Администратор'),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(adminActionNames[action] ?? action, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (hasNote) ...[
            const SizedBox(height: 2),
            Text(isMessage ? note! : tr('Причина: $note', 'Сабаб: $note'), style: TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 4),
          Text(date, style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
      if (code.startsWith('CH-')) {
        // Переписка: переписку админ не читает (приватность), но видит участников и открывает их профили.
        final conv = await _db
            .from('conversations')
            .select('id, kind, buyer_id, seller_id, listing_id')
            .eq('public_id', code)
            .maybeSingle();
        if (!mounted) return;
        if (conv == null) {
          messenger.showSnackBar(SnackBar(content: Text(tr('Чат с таким ID не найден', 'Чат бо ин ID ёфт нашуд'))));
          return;
        }
        final ids = [conv['buyer_id'], conv['seller_id']].whereType<String>().toList();
        final profs = ids.isEmpty
            ? <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(
                await _db.from('profiles').select('id, name, public_id').inFilter('id', ids));
        final byId = {for (final p in profs) p['id'] as String: p};
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Чат $code'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(tr('Тип: ${conv[\'kind\'] ?? \'—\'}', 'Намуд: ${conv[\'kind\'] ?? \'—\'}'), style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 12),
                for (final entry in [(tr('Покупатель', 'Харидор'), conv['buyer_id']), (tr('Продавец', 'Фурӯшанда'), conv['seller_id'])])
                  if (entry.$2 is String && byId[entry.$2 as String] != null)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => UserProfileScreen(userId: entry.$2 as String),
                        ));
                      },
                      child: Text(
                        '${entry.$1}: ${byId[entry.$2 as String]!['name'] ?? '—'} · ${byId[entry.$2 as String]!['public_id'] ?? ''}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Закрыть', 'Пӯшидан')))],
          ),
        );
        _idCtrl.clear();
        return;
      }
      if (code.startsWith('PR-')) {
        // Аккаунт пользователя: открываем его профиль.
        final prof = await _db.from('profiles').select('id').eq('public_id', code).maybeSingle();
        if (!mounted) return;
        if (prof == null) {
          messenger.showSnackBar(SnackBar(content: Text(tr('Аккаунт с таким ID не найден', 'Ҳисоб бо ин ID ёфт нашуд'))));
          return;
        }
        final userId = prof['id'] as String;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
        );
        _idCtrl.clear();
        return;
      }
      final row = code.startsWith('OB-')
          ? await _db.from('listings').select('id').eq('public_id', code).maybeSingle()
          : await _db.from('listings').select('id').eq('id', id).maybeSingle();
      if (!mounted) return;
      if (row == null) {
        messenger.showSnackBar(SnackBar(content: Text(tr('Объявление с таким ID не найдено', 'Эълон бо ин ID ёфт нашуд'))));
        return;
      }
      final uuid = row['id'] as String;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AdminThreadScreen(listingId: uuid)),
      );
      _idCtrl.clear();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Проверьте ID объявления', 'ID-и эълонро санҷед'))));
    } finally {
      if (mounted) setState(() => _searching = false);
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
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.title),title: Text(tr('Поиск по ID', 'Ҷустуҷӯ бо ID'))),
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
                  style: const TextStyle(color: AppColors.onLight),
                  decoration: InputDecoration(
                    hintText: tr('Например OB-1A2B3C4D, PR-1A2B3C4D или CH-1A2B3C4D', 'Масалан OB-1A2B3C4D, PR-1A2B3C4D ё CH-1A2B3C4D'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFE6ECEA),
                    hintStyle: const TextStyle(color: AppColors.hintOnLight),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GreenButton(
                  onPressed: _searching ? null : _search,
                  child: Text(tr('Найти', 'Ёфтан')),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 72, color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    tr('Поиск по ID', 'Ҷустуҷӯ бо ID'),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 6),
                  Text(
                    tr('Введите ID объявления (OB-…) или аккаунта (PR-…),\nчтобы открыть его', 'ID-и эълон (OB-…) ё ҳисоби (PR-…)-ро ворид кунед,\nто кушода шавад'),
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
