import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'call_options_sheet.dart';
import 'chat_attachments.dart';
import 'chat_image.dart';
import 'notify_store.dart';
import 'review_dialog.dart';
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
/// Время сообщения по Таджикистану (Душанбе, UTC+5, без летнего времени).
String _tajikTime(String? iso) {
  if (iso == null) return '';
  final utc = DateTime.tryParse(iso)?.toUtc();
  if (utc == null) return '';
  final t = utc.add(const Duration(hours: 5));
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.title,
    this.staffTicket = false,
    this.canFinish = true,
    this.joinMode = false,
    this.initialText,
  });

  final String conversationId;
  final String title;

  /// Сотрудник открыл чат пользователей по ID: сначала нужно присоединиться.
  final bool joinMode;

  /// Текст, который появится в поле ввода (например, ID чата для поддержки).
  final String? initialText;

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

  Stream<List<Map<String, dynamic>>>? _stream;
  bool _isStaff = false;

  void _startStream() {
    _stream = Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId);
  }

  Future<void> _loadStaff() async {
    final me = _me;
    if (me == null) return;
    try {
      final prof = await Supabase.instance.client
          .from('profiles')
          .select('is_admin')
          .eq('id', me)
          .maybeSingle();
      if (mounted) setState(() => _isStaff = prof?['is_admin'] == true);
    } catch (_) {
      // Без этого ID чата просто не будет кликабельным
    }
  }

  /// Сотрудник присоединяется к чату пользователей.
  Future<void> _join() async {
    final me = _me;
    if (me == null) return;
    try {
      await Supabase.instance.client.from('conversation_members').upsert(
        {'conversation_id': widget.conversationId, 'user_id': me},
        onConflict: 'conversation_id,user_id',
      );
      if (mounted) setState(_startStream);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось присоединиться к чату')),
      );
    }
  }

  Widget _joinBox() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Вы ещё не в этом чате',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Присоединитесь, чтобы видеть переписку и отвечать',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _join, child: const Text('Присоединиться')),
          ],
        ),
      ),
    );
  }

  /// Открыть поддержку с ID этого чата в поле ввода.
  Future<void> _contactSupport() async {
    try {
      final id = await findOrCreateConversation(kind: 'support');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: id,
            title: 'Поддержка',
            initialText: 'ID чата: ${widget.conversationId}\n',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть поддержку')),
      );
    }
  }

  /// Текст сообщения. Для сотрудника ID чата в тексте нажимается и открывает чат.
  Widget _bodyText(String body, TextStyle style) {
    final re = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}');
    final matches = re.allMatches(body).toList();
    if (matches.isEmpty || !_isStaff) return Text(body, style: style);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in matches) {
      if (m.start > last) spans.add(TextSpan(text: body.substring(last, m.start)));
      final id = m.group(0)!;
      spans.add(TextSpan(
        text: id,
        style: const TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700),
        recognizer: TapGestureRecognizer()
          ..onTap = () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    conversationId: id,
                    title: 'Чат пользователя',
                    joinMode: true,
                  ),
                ),
              ),
      ));
      last = m.end;
    }
    if (last < body.length) spans.add(TextSpan(text: body.substring(last)));
    return Text.rich(TextSpan(style: style, children: spans));
  }

  String? get _me => Supabase.instance.client.auth.currentUser?.id;

  /// Профили собеседников (имя и фото) для аватаров у сообщений.
  final Map<String, Map<String, dynamic>> _profiles = {};
  final Set<String> _requested = {};

  /// Отзыв продавцу: покупатель видит предложение, когда продавец ответил.
  Map<String, dynamic>? _conv;
  bool _showReview = false;
  int _msgCount = -1;

  Future<void> _loadConv() async {
    try {
      final row = await Supabase.instance.client
          .from('conversations')
          .select('kind, buyer_id, seller_id, review_dismissed, public_id')
          .eq('id', widget.conversationId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _conv = row);
      await _checkReview();
    } catch (_) {
      // Без этого просто не покажем предложение оставить отзыв
    }
  }

  Future<void> _checkReview() async {
    final c = _conv;
    final me = _me;
    if (c == null || me == null) return;
    final seller = c['seller_id'] as String?;
    final eligible = c['kind'] == 'listing' &&
        c['buyer_id'] == me &&
        seller != null &&
        seller != me &&
        c['review_dismissed'] != true;
    if (!eligible) {
      if (mounted && _showReview) setState(() => _showReview = false);
      return;
    }
    try {
      final db = Supabase.instance.client;
      final replied = await db
          .from('messages')
          .select('id')
          .eq('conversation_id', widget.conversationId)
          .eq('sender_id', seller)
          .limit(1);
      final reviewed = await db
          .from('reviews')
          .select('id')
          .eq('reviewed_id', seller)
          .eq('author_id', me)
          .limit(1);
      final show = replied.isNotEmpty && reviewed.isEmpty;
      if (mounted && show != _showReview) setState(() => _showReview = show);
    } catch (_) {
      // Ошибку проверки не показываем: предложение просто не появится
    }
  }

  Future<void> _dismissReview() async {
    setState(() => _showReview = false);
    try {
      await Supabase.instance.client
          .from('conversations')
          .update({'review_dismissed': true})
          .eq('id', widget.conversationId);
    } catch (_) {
      // Если не сохранилось, предложение может появиться снова
    }
  }

  Future<void> _writeReview() async {
    final seller = _conv?['seller_id'] as String?;
    if (seller == null) return;
    final sent = await showReviewSheet(
      context,
      sellerId: seller,
      conversationId: widget.conversationId,
    );
    if (!sent || !mounted) return;
    setState(() => _showReview = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Спасибо за отзыв!')),
    );
  }

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
    if (widget.initialText != null) _ctrl.text = widget.initialText!;
    if (!widget.joinMode) _startStream();
    _loadStaff();
    _loadConv();
  }

  @override
  void dispose() {
    // Вышли из переписки, а отзыв ещё не оставлен: напоминаем баннером сверху
    if (_showReview) {
      final id = widget.conversationId;
      final seller = _conv?['seller_id'] as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTopBanner(
          'Оставьте отзыв продавцу',
          'Вы общались с продавцом. Нажмите, чтобы написать отзыв',
          onTap: () {
            final ctx = appNavigatorKey.currentState?.overlay?.context;
            if (ctx == null || seller == null) return;
            showReviewSheet(ctx, sellerId: seller, conversationId: id);
          },
          secondaryLabel: 'Отказать',
          onSecondary: () async {
            try {
              await Supabase.instance.client
                  .from('conversations')
                  .update({'review_dismissed': true})
                  .eq('id', id);
            } catch (_) {
              // Если не сохранилось, предложение может появиться снова
            }
          },
        );
      });
    }
    markChatRead(widget.conversationId);
    _ctrl.dispose();
    _recorder.dispose();
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

  /// Отправка фото из галереи или с камеры. Хранится в закрытом хранилище, доступ только участникам.
  Future<void> _attachImage() async {
    if (_sending) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Галерея'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Камера'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Фото больше 10 МБ')));
      }
      return;
    }

    setState(() => _sending = true);
    try {
      final db = Supabase.instance.client;
      final path = '${widget.conversationId}/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await db.storage.from('chat-attachments').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      await db.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _me,
        'body': '📷 Фото',
        'attachment_url': path,
        'attachment_kind': 'image',
        'attachment_name': file.name,
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить фото')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  final _recorder = AudioRecorder();
  bool _recording = false;

  void _snack(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Загружает вложение в закрытое хранилище и отправляет сообщение с ним.
  Future<void> _sendAttachment({
    required Uint8List bytes,
    required String kind,
    required String body,
    required String name,
    required String ext,
    required String contentType,
  }) async {
    final db = Supabase.instance.client;
    final path = '${widget.conversationId}/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage.from('chat-attachments').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    await db.from('messages').insert({
      'conversation_id': widget.conversationId,
      'sender_id': _me,
      'body': body,
      'attachment_url': path,
      'attachment_kind': kind,
      'attachment_name': name,
    });
  }

  /// Выбор файла с телефона или компьютера (до 20 МБ).
  Future<void> _attachFile() async {
    if (_sending) return;
    final result = await FilePicker.platform.pickFiles(withData: true);
    final picked = result?.files.single;
    final bytes = picked?.bytes;
    if (picked == null || bytes == null) return;
    if (bytes.length > 20 * 1024 * 1024) {
      _snack('Файл больше 20 МБ');
      return;
    }
    final raw = (picked.extension ?? '').toLowerCase();
    final ext = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(raw) ? raw : 'bin';
    setState(() => _sending = true);
    try {
      await _sendAttachment(
        bytes: bytes,
        kind: 'file',
        body: '📎 ${picked.name}',
        name: picked.name,
        ext: ext,
        contentType: 'application/octet-stream',
      );
    } catch (_) {
      _snack('Не удалось отправить файл');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Нажал — начинается запись, нажал ещё раз — запись уходит в чат.
  Future<void> _toggleRecord() async {
    if (_sending) return;
    if (!_recording) {
      if (!await _recorder.hasPermission()) {
        _snack('Разрешите доступ к микрофону');
        return;
      }
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus), path: 'voice');
      setState(() => _recording = true);
      return;
    }
    final recordedUrl = await _recorder.stop();
    setState(() => _recording = false);
    if (recordedUrl == null) return;
    setState(() => _sending = true);
    try {
      final bytes = await XFile(recordedUrl).readAsBytes();
      await _sendAttachment(
        bytes: bytes,
        kind: 'audio',
        body: '🎤 Голосовое',
        name: 'voice.webm',
        ext: 'webm',
        contentType: 'audio/webm',
      );
    } catch (_) {
      _snack('Не удалось отправить голосовое');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static final _uuidRe = RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}');

  /// Кнопка для сотрудника под сообщением в поддержке, где есть ID чата.
  List<Widget> _openChatButtons(String body) {
    if (!_isStaff || _conv?['kind'] != 'support') return const [];
    final id = _uuidRe.firstMatch(body)?.group(0);
    if (id == null) return const [];
    return [
      const SizedBox(height: 4),
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: id,
              title: 'Чат пользователя',
              joinMode: true,
            ),
          ),
        ),
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Открыть чат пользователя'),
      ),
    ];
  }

  void _callInternet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Звонок через Интернет скоро будет доступен')),
    );
  }

  /// Обычный звонок собеседнику (покупатель звонит продавцу и наоборот).
  Future<void> _callDirect() async {
    final c = _conv;
    final me = _me;
    if (c == null || me == null) return;
    final otherId = me == c['buyer_id'] ? c['seller_id'] : c['buyer_id'];
    if (otherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Собеседник не найден')));
      return;
    }
    final p = await Supabase.instance.client
        .from('profiles')
        .select('phone')
        .eq('id', otherId)
        .maybeSingle();
    final phone = p?['phone'] as String?;
    if (!mounted) return;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Номер собеседника пока не указан')),
      );
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть звонок')),
      );
    }
  }

  Future<void> _setTicket(String status) async {
    try {
      await Supabase.instance.client.rpc('set_ticket_status', params: {
        'cid': widget.conversationId,
        'new_status': status,
      });
      if (!mounted) return;
      if (status == 'answered') {
        // Завершённое обращение скрывается из списка для сотрудников — возвращаемся назад
        Navigator.of(context).pop();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Обращение: на помощи')),
      );
    } catch (e) {
      if (!mounted) return;
      final reason = e is PostgrestException ? ': ${e.message}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить статус$reason')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            if (_conv?['public_id'] != null)
              Text('ID чата: ${_conv!['public_id']}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          if (_conv != null && _conv!['kind'] != 'support')
            IconButton(
              tooltip: 'Позвонить',
              icon: const Icon(Icons.call_rounded),
              onPressed: () => showCallOptionsSheet(
                context,
                onInternet: _callInternet,
                onDirect: _callDirect,
              ),
            ),
          if (!widget.joinMode && !widget.staffTicket && _conv?['kind'] != 'support')
            PopupMenuButton<String>(
              onSelected: (_) => _contactSupport(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'support', child: Text('Поддержка')),
              ],
            ),
        ],
      ),
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
          if (_showReview)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Оставьте отзыв продавцу',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(onPressed: _dismissReview, child: const Text('Отказать')),
                  FilledButton(onPressed: _writeReview, child: const Text('Оставить отзыв')),
                ],
              ),
            ),
          Expanded(
            child: _stream == null
                ? _joinBox()
                : StreamBuilder<List<Map<String, dynamic>>>(
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
                // Новое сообщение могло быть ответом продавца: перепроверяем предложение
                if (items.length != _msgCount) {
                  _msgCount = items.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) => _checkReview());
                }
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (m['attachment_kind'] == 'image' && m['attachment_url'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: ChatImage(path: m['attachment_url'] as String),
                            ),
                          if (m['attachment_kind'] == 'audio' && m['attachment_url'] != null)
                            ChatAudioTile(path: m['attachment_url'] as String, mine: mine),
                          if (m['attachment_kind'] == 'file' && m['attachment_url'] != null)
                            ChatFileTile(
                              path: m['attachment_url'] as String,
                              name: (m['attachment_name'] ?? 'Файл') as String,
                              mine: mine,
                            ),
                          if (m['attachment_kind'] == null)
                            _bodyText(
                              m['body'] as String,
                              TextStyle(color: mine ? Colors.white : AppColors.ink, height: 1.3),
                            ),
                        ],
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
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                bubble,
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                                  child: Text(
                                    _tajikTime(m['created_at'] as String?),
                                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                                  ),
                                ),
                                ..._openChatButtons(m['body'] as String),
                              ],
                            ),
                          ),
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
                  IconButton(
                    onPressed: _sending ? null : _attachImage,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _attachFile,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
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
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ctrl,
                    builder: (_, value, __) {
                      if (value.text.trim().isNotEmpty) {
                        return IconButton.filled(
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                        );
                      }
                      return IconButton.filled(
                        style: _recording
                            ? IconButton.styleFrom(backgroundColor: Colors.red)
                            : null,
                        onPressed: _sending ? null : _toggleRecord,
                        icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                      );
                    },
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
