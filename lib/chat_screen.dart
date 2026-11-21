import 'dart:async';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'lang_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'browser_theme_color.dart';
import 'call_options_sheet.dart';
import 'call_screen.dart';
import 'chat_attachments.dart';
import 'chat_image.dart';
import 'notify_store.dart';
import 'review_dialog.dart';
import 'seller_contacts.dart';
import 'block_store.dart';
import 'user_complaints.dart';
import 'theme.dart';
import 'glass_widgets.dart';
import 'user_profile_screen.dart';
import 'green_button.dart';

/// Находит переписку текущего пользователя или создаёт новую.
/// kind: 'support' (чат с командой) или 'listing' (чат по объявлению).
Future<String> findOrCreateConversation({required String kind, String? listingId, String? sellerId}) async {
  final db = Supabase.instance.client;
  final me = db.auth.currentUser!.id;

  var query = db.from('conversations').select('id').eq('kind', kind);
  if (listingId != null) {
    query = query.eq('buyer_id', me).eq('listing_id', listingId);
    if (sellerId != null) query = query.eq('seller_id', sellerId);
  } else if (sellerId != null) {
    // Личная переписка одна на пару: ищем её в обе стороны (кто первым написал).
    query = query.or(
      'and(buyer_id.eq.$me,seller_id.eq.$sellerId),and(buyer_id.eq.$sellerId,seller_id.eq.$me)',
    );
  } else {
    query = query.eq('buyer_id', me);
  }

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
DateTime? _tajikLocal(String? iso) {
  if (iso == null) return null;
  final utc = DateTime.tryParse(iso)?.toUtc();
  return utc?.add(const Duration(hours: 5));
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Дата и время сообщения по Таджикистану: «15.11.2026 13:19».
String _tajikTime(String? iso) {
  final t = _tajikLocal(iso);
  if (t == null) return '';
  return '${_two(t.day)}.${_two(t.month)}.${t.year} ${_two(t.hour)}:${_two(t.minute)}';
}

/// Только дата по Таджикистану, для разделителя между днями.
String _tajikDay(String? iso) {
  final t = _tajikLocal(iso);
  if (t == null) return '';
  return '${_two(t.day)}.${_two(t.month)}.${t.year}';
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

  // Статус собеседника: онлайн, печатает, записывает голос.
  RealtimeChannel? _peerCh;
  Timer? _presenceTimer;
  Timer? _peerActionTimer;
  Timer? _recActivityTimer;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _otherSeen;
  String? _peerAction; // 'typing' | 'recording'

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
        SnackBar(content: Text(tr('Не удалось присоединиться к чату', 'Ба гуфтугӯ пайваст шудан муяссар нашуд'))),
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
            Text(tr('Вы ещё не в этом чате', 'Шумо ҳанӯз дар ин гуфтугӯ нестед'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              tr('Присоединитесь, чтобы видеть переписку и отвечать', 'Пайваст шавед, то мактубҳоро бинед ва ҷавоб диҳед'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            GreenButton(onPressed: _join, child: Text(tr('Присоединиться', 'Пайваст шудан'))),
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
            title: tr('Поддержка', 'Дастгирӣ'),
            initialText: 'ID чата: ${widget.conversationId}\n',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть поддержку', 'Кушодани дастгирӣ муяссар нашуд'))),
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
                    title: tr('Чат пользователя', 'Гуфтугӯи корбар'),
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

  /// Контакты собеседника, если он разрешил показ (иконки WhatsApp и Telegram в шапке).
  SellerContacts? _peerContacts;

  Future<void> _loadPeerContacts() async {
    final id = _otherId;
    if (id == null) return;
    final c = await SellerContacts.peer(id);
    if (mounted) setState(() => _peerContacts = c);
  }

  /// Открывает мессенджер: сначала приложение (appUri), если не получилось — обычная ссылка (uri).
  Future<void> _openMessenger(Uri? uri, String name, {Uri? appUri}) async {
    if (uri == null) return;
    var ok = false;
    if (appUri != null) {
      try {
        ok = await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть $name', 'Кушодани $name муяссар нашуд'))),
      );
    }
  }

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
      _loadPresence();
      _loadPeerContacts();
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
      SnackBar(content: Text(tr('Спасибо за отзыв!', 'Ташаккур барои бознигарӣ!'))),
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
    setBrowserThemeColor(darkMode.value ? '#0C1513' : '#E7EEEB');
    markChatRead(widget.conversationId);
    if (widget.initialText != null) _ctrl.text = widget.initialText!;
    if (!widget.joinMode) _startStream();
    _loadStaff();
    _loadConv();
    _ctrl.addListener(_onInputChanged);
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadPresence());
    _startPeerChannel();
  }

  @override
  void dispose() {
    setBrowserThemeColor(darkMode.value ? '#0C1513' : '#F4F7F6');
    // Вышли из переписки, а отзыв ещё не оставлен: напоминаем баннером сверху
    if (_showReview) {
      final id = widget.conversationId;
      final seller = _conv?['seller_id'] as String?;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showTopBanner(
          tr('Оставьте отзыв продавцу', 'Ба фурӯшанда бознигарӣ гузоред'),
          tr('Вы общались с продавцом. Нажмите, чтобы написать отзыв', 'Шумо бо фурӯшанда муошират кардед. Барои навиштани бознигарӣ пахш кунед'),
          onTap: () {
            final ctx = appNavigatorKey.currentState?.overlay?.context;
            if (ctx == null || seller == null) return;
            showReviewSheet(ctx, sellerId: seller, conversationId: id);
          },
          secondaryLabel: tr('Отказать', 'Рад кардан'),
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
    _presenceTimer?.cancel();
    _peerActionTimer?.cancel();
    _recActivityTimer?.cancel();
    _peerCh?.unsubscribe();
    _ctrl.dispose();
    _recTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  bool get _isSeller => _conv?['seller_id'] == _me;

  /// Собеседник в этом чате (для поддержки статуса нет).
  String? get _otherId {
    final c = _conv;
    final me = _me;
    if (c == null || me == null || c['kind'] == 'support') return null;
    return (me == c['buyer_id'] ? c['seller_id'] : c['buyer_id']) as String?;
  }

  Future<void> _loadPresence() async {
    final id = _otherId;
    if (id == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('last_seen_at')
          .eq('id', id)
          .maybeSingle();
      final iso = row?['last_seen_at'] as String?;
      if (mounted) {
        setState(() => _otherSeen = iso == null ? null : DateTime.tryParse(iso)?.toLocal());
      }
    } catch (_) {
      // Без статуса просто не покажем строку под именем
    }
  }

  /// Канал чата, по которому передаём «печатает» и «записывает голос».
  void _startPeerChannel() {
    final ch = Supabase.instance.client.channel('chat-${widget.conversationId}');
    ch.onBroadcast(
      event: 'activity',
      callback: (payload) {
        if (payload['user'] == _me || !mounted) return;
        final state = payload['state'] as String?;
        final active = state == 'typing' || state == 'recording';
        _peerActionTimer?.cancel();
        setState(() => _peerAction = active ? state : null);
        if (active) {
          // Если собеседник перестал печатать, статус гаснет через 3 секунды.
          _peerActionTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _peerAction = null);
          });
        }
      },
    );
    ch.subscribe();
    _peerCh = ch;
  }

  void _sendActivity(String state) {
    final ch = _peerCh;
    final me = _me;
    if (ch == null || me == null || _otherId == null) return;
    if (state == 'typing') {
      final now = DateTime.now();
      if (now.difference(_lastTypingSent) < const Duration(seconds: 2)) return;
      _lastTypingSent = now;
    }
    ch.sendBroadcastMessage(event: 'activity', payload: {'user': me, 'state': state}).catchError((_) {});
  }

  void _onInputChanged() {
    if (_ctrl.text.trim().isNotEmpty) _sendActivity('typing');
  }

  /// Строка под именем собеседника: онлайн, печатает, записывает голос или время захода.
  Widget? _statusWidget() {
    if (_otherId == null) return null;
    const base = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    if (_peerAction == 'typing') {
      return Text('• • • ${tr('печатает', 'навишта истодааст')}',
          style: base.copyWith(color: AppColors.primary));
    }
    if (_peerAction == 'recording') {
      return Text(tr('записывает голос', 'паёми овозӣ сабт мекунад'),
          style: base.copyWith(color: AppColors.primary));
    }
    final seen = _otherSeen;
    if (seen == null) return null;
    if (DateTime.now().difference(seen) < const Duration(minutes: 2)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Color(0xFF24B36B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(tr('В сети', 'Онлайн'), style: base.copyWith(color: const Color(0xFF24B36B))),
        ],
      );
    }
    return Text(_lastSeenText(seen), style: base.copyWith(color: AppColors.muted, fontWeight: FontWeight.w500));
  }

  static List<String> get _quick => [
    tr('Да, в наличии', 'Ҳа, дастрас аст'),
    tr('Можно посмотреть сегодня?', 'Имрӯз дидан мумкин аст?'),
    tr('Цена окончательная', 'Нарх ниҳоӣ аст'),
    tr('Уточните, пожалуйста, детали', 'Лутфан тафсилотро равшан кунед'),
    tr('Спасибо, свяжусь позже', 'Ташаккур, баъдтар тамос мегирам'),
  ];

  /// Быстрый ответ: подставляет текст в поле, отправляет продавец сам.
  Widget _quickReplies() => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _quick.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ActionChip(
            label: Text(_quick[i]),
            onPressed: () {
              _ctrl.text = _quick[i];
              _ctrl.selection = TextSelection.collapsed(offset: _quick[i].length);
            },
          ),
        ),
      );

  /// Заблокирован ли собеседник этим пользователем.
  bool get _blocked {
    final id = _otherId;
    return id != null && BlockStore.isBlocked(id);
  }

  Future<void> _toggleBlock() async {
    final id = _otherId;
    if (id == null) return;
    final nowBlocked = await BlockStore.toggle(id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowBlocked
          ? tr('Собеседник заблокирован', 'Суҳбатдош баста шуд')
          : tr('Блокировка снята', 'Баст бекор шуд')),
    ));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    if (_blocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Снимите блокировку, чтобы писать собеседнику',
            'Барои навиштан ба суҳбатдош баст бекор кунед')),
      ));
      return;
    }
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'conversation_id': widget.conversationId,
        'sender_id': _me,
        'body': text,
      });
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        final limited = '$e'.contains('rate_limited');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(limited
                ? tr('Слишком много сообщений, подождите минуту', 'Паёмҳо зиёданд, як дақиқа интизор шавед')
                : tr('Не удалось отправить сообщение', 'Фиристодани паём муяссар нашуд')),
          ),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassSheet(child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('Галерея', 'Галерея')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(tr('Камера', 'Камера')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      )),
    );
    if (source == null) return;

    final file = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Фото больше 10 МБ', 'Акс аз 10 МБ зиёд аст'))));
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
          SnackBar(content: Text(tr('Не удалось отправить фото', 'Фиристодани акс муяссар нашуд'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  final _recorder = AudioRecorder();
  bool _recording = false;
  Timer? _recTimer;
  Duration _recElapsed = Duration.zero;

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
      _snack(tr('Файл больше 20 МБ', 'Файл аз 20 МБ зиёд аст'));
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
      _snack(tr('Не удалось отправить файл', 'Фиристодани файл муяссар нашуд'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Отмена записи: запись останавливается и не отправляется.
  Future<void> _cancelRecord() async {
    _recTimer?.cancel();
    _recActivityTimer?.cancel();
    _sendActivity('idle');
    try {
      await _recorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _recording = false;
        _recElapsed = Duration.zero;
      });
    }
  }

  /// Нажал — начинается запись, нажал ещё раз — запись уходит в чат.
  Future<void> _toggleRecord() async {
    if (_sending) return;
    if (!_recording) {
      if (!await _recorder.hasPermission()) {
        _snack(tr('Разрешите доступ к микрофону', 'Дастрасӣ ба микрофонро иҷозат диҳед'));
        return;
      }
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.opus), path: 'voice');
      _recElapsed = Duration.zero;
      _recTimer?.cancel();
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recElapsed += const Duration(seconds: 1));
      });
      setState(() => _recording = true);
      _sendActivity('recording');
      _recActivityTimer?.cancel();
      _recActivityTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendActivity('recording'));
      return;
    }
    _recTimer?.cancel();
    _recActivityTimer?.cancel();
    _sendActivity('idle');
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
      _snack(tr('Не удалось отправить голосовое', 'Фиристодани паёми овозӣ муяссар нашуд'));
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
              title: tr('Чат пользователя', 'Гуфтугӯи корбар'),
              joinMode: true,
            ),
          ),
        ),
        icon: const Icon(Icons.login_rounded, size: 18),
        label: Text(tr('Открыть чат пользователя', 'Кушодани гуфтугӯи корбар')),
      ),
    ];
  }

  void _callInternet() {
    final c = _conv;
    final me = _me;
    if (c == null || me == null) return;
    final otherId = me == c['buyer_id'] ? c['seller_id'] : c['buyer_id'];
    if (otherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Собеседник не найден', 'Суҳбатдош ёфт нашуд'))));
      return;
    }
    final channel = pairChannel(me, otherId as String);
    inviteToCall(calleeId: otherId, channel: channel).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Собеседник не получил уведомление о звонке. Попросите его открыть приложение', 'Суҳбатдош огоҳии занг нагирифт. Аз ӯ хоҳиш кунед, ки барномаро кушояд')),
        ));
      }
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          channel: channel,
          title: widget.title,
          conversationId: widget.conversationId,
        ),
      ),
    );
  }

  /// Обычный звонок собеседнику (покупатель звонит продавцу и наоборот).
  Future<void> _callDirect() async {
    final c = _conv;
    final me = _me;
    if (c == null || me == null) return;
    final otherId = me == c['buyer_id'] ? c['seller_id'] : c['buyer_id'];
    if (otherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Собеседник не найден', 'Суҳбатдош ёфт нашуд'))));
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
        SnackBar(content: Text(tr('Номер собеседника пока не указан', 'Рақами суҳбатдош ҳанӯз нишон дода нашудааст'))),
      );
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть звонок', 'Кушодани занг муяссар нашуд'))),
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
        SnackBar(content: Text(tr('Обращение: на помощи', 'Муроҷиат: ба кумак'))),
      );
    } catch (e) {
      if (!mounted) return;
      final reason = e is PostgrestException ? ': ${e.message}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось изменить статус$reason', 'Иваз кардани ҳолат муяссар нашуд$reason'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _chatBg,
      appBar: AppBar(
        // Непрозрачная шапка: контент не просвечивает сквозь неё при прокрутке.
        backgroundColor: _chatBg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Нажатие на имя открывает профиль собеседника.
          onTap: _otherId == null ? null : () => _openProfile(_otherId!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title),
              if (_statusWidget() != null) _statusWidget()!,
              if (_conv?['public_id'] != null)
                Text('ID чата: ${_conv!['public_id']}',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
        actions: [
          // Контакты собеседника в мессенджерах (только если он разрешил показ)
          if (_peerContacts?.whatsappUri != null)
            IconButton(
              tooltip: tr('Написать в WhatsApp', 'Навиштан дар WhatsApp'),
              icon: Image.asset('assets/icons/whatsapp_logo.png', width: 26, height: 26),
              onPressed: () => _openMessenger(_peerContacts!.whatsappUri, 'WhatsApp'),
            ),
          if (_peerContacts?.telegramUri != null)
            IconButton(
              tooltip: tr('Написать в Telegram', 'Навиштан дар Telegram'),
              icon: Image.asset('assets/icons/telegram_logo.png', width: 26, height: 26),
              onPressed: () => _openMessenger(
                _peerContacts!.telegramUri,
                'Telegram',
                appUri: _peerContacts!.telegramAppUri,
              ),
            ),
          if (_conv != null && _conv!['kind'] != 'support')
            IconButton(
              tooltip: tr('Позвонить', 'Занг задан'),
              icon: const Icon(Icons.call_rounded),
              onPressed: () => showCallOptionsSheet(
                context,
                onInternet: _callInternet,
                onDirect: _callDirect,
              ),
            ),
          if (!widget.joinMode && !widget.staffTicket && _conv?['kind'] != 'support')
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'block') {
                  _toggleBlock();
                } else if (v == 'complaint') {
                  final id = _otherId;
                  if (id != null) showUserComplaintDialog(context, id);
                } else {
                  _contactSupport();
                }
              },
              itemBuilder: (_) => [
                if (_otherId != null)
                  PopupMenuItem(
                    value: 'block',
                    child: Text(_blocked
                        ? tr('Снять блокировку', 'Баст бекор кардан')
                        : tr('Заблокировать собеседника', 'Суҳбатдошро баст кардан')),
                  ),
                if (_otherId != null)
                  PopupMenuItem(
                    value: 'complaint',
                    child: Text(tr('Пожаловаться на собеседника', 'Аз суҳбатдош шикоят кардан')),
                  ),
                PopupMenuItem(value: 'support', child: Text(tr('Поддержка', 'Дастгирӣ'))),
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
                      label: Text(tr('На помощь', 'Ба кумак')),
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
                        label: Text(tr('Завершить', 'Анҷом додан')),
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
                  Expanded(
                    child: Text(
                      tr('Оставьте отзыв продавцу', 'Ба фурӯшанда бознигарӣ гузоред'),
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(onPressed: _dismissReview, child: Text(tr('Отказать', 'Рад кардан'))),
                  GreenButton(onPressed: _writeReview, child: Text(tr('Оставить отзыв', 'Бознигарӣ гузоштан'))),
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
                  return Center(child: Text(tr('Не удалось загрузить переписку', 'Боргирии гуфтугӯ муяссар нашуд')));
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
                  return Center(
                    child: Text(tr('Напишите первое сообщение', 'Аввалин паёмро нависед'), style: TextStyle(color: AppColors.muted)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: const BoxConstraints(maxWidth: 260),
                      decoration: _raised(
                        color: mine ? _mineBubble : _theirBubble,
                        radius: 18,
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
                              name: (m['attachment_name'] ?? tr('Файл', 'Файл')) as String,
                              mine: mine,
                            ),
                          if (m['attachment_kind'] == 'call')
                            _CallEntry(value: m['attachment_url'] as String?, mine: mine),
                          if (m['attachment_kind'] == null)
                            _bodyText(
                              m['body'] as String,
                              TextStyle(color: mine ? AppColors.title : AppColors.ink, height: 1.3, fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    );
                    final day = _tajikDay(m['created_at'] as String?);
                    final prevDay = items.length - 1 - i > 0
                        ? _tajikDay(items[items.length - 2 - i]['created_at'] as String?)
                        : null;
                    final showDay = day.isNotEmpty && day != prevDay;
                    final row = _Appear(
                      key: ValueKey(m['id'] ?? i),
                      child: Padding(
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
                                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                                  ),
                                ),
                                ..._openChatButtons(m['body'] as String),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    );
                    if (!showDay) return row;
                    return Column(
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(day, style: const TextStyle(color: Colors.black, fontSize: 12)),
                          ),
                        ),
                        row,
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_isSeller) _quickReplies(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
              child: Row(
                children: [
                  if (!_recording) ...[
                    IconButton(
                      onPressed: _sending ? null : _attachImage,
                      icon: const Icon(Icons.image_outlined),
                    ),
                    IconButton(
                      onPressed: _sending ? null : _attachFile,
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                  ],
                  Expanded(
                    child: _recording
                        ? _RecordingBar(elapsed: _recElapsed, onCancel: _cancelRecord)
                        : _GlowInput(controller: _ctrl),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ctrl,
                    builder: (_, value, __) {
                      if (_recording) {
                        return _PulseSendButton(onPressed: _sending ? null : _toggleRecord);
                      }
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

/// Фон чата и «объёмные» цвета пузырей в стиле мягкого неморфизма.
Color get _chatBg => darkMode.value ? AppColors.background : const Color(0xFFE7EEEB);
Color get _mineBubble => darkMode.value ? const Color(0xFF1E4A40) : const Color(0xFFD6EDE5);
Color get _theirBubble => AppColors.surface;

/// Приподнятая мягкая поверхность: светлый блик сверху слева и тень снизу справа.
BoxDecoration _raised({required Color color, double radius = 18}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8, offset: const Offset(-3, -3)),
        BoxShadow(color: const Color(0xFF3E5F55).withValues(alpha: 0.16), blurRadius: 10, offset: const Offset(4, 5)),
      ],
    );

/// Сообщение появляется плавно: поднимается снизу и проявляется.
class _Appear extends StatelessWidget {
  const _Appear({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: c),
      ),
      child: child,
    );
  }
}

/// Поле ввода-капсула. Когда в него нажали, по краю бежит переливающаяся подсветка.
class _GlowInput extends StatefulWidget {
  const _GlowInput({required this.controller});

  final TextEditingController controller;

  @override
  State<_GlowInput> createState() => _GlowInputState();
}

class _GlowInputState extends State<_GlowInput> with SingleTickerProviderStateMixin {
  final _focus = FocusNode();
  late final AnimationController _glow =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final dx = -1.0 + 2 * _glow.value;
        return Container(
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: focused
                ? LinearGradient(
                    begin: Alignment(dx - 1, 0),
                    end: Alignment(dx + 1, 0),
                    colors: const [AppColors.primary, AppColors.saffron, AppColors.primary],
                  )
                : null,
            color: focused ? null : AppColors.surface,
            boxShadow: [
              BoxShadow(color: Colors.white.withValues(alpha: 0.9), blurRadius: 8, offset: const Offset(-3, -3)),
              BoxShadow(
                color: const Color(0xFF3E5F55).withValues(alpha: 0.14),
                blurRadius: 10,
                offset: const Offset(3, 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22.5),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: _focus,
          minLines: 1,
          maxLines: 4,
          style: TextStyle(color: AppColors.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: tr('Сообщение', 'Паём'),
            hintStyle: TextStyle(color: AppColors.muted),
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }
}

/// Строка записи: мигающая красная точка, таймер и «‹ Отмена».
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.elapsed, required this.onCancel});

  final Duration elapsed;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    final m = elapsed.inMinutes.toString();
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: _raised(color: _theirBubble, radius: 24),
      child: Row(
        children: [
          const _BlinkDot(),
          const SizedBox(width: 8),
          Text(
            '$m:$s',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onCancel(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded, color: AppColors.ruby, size: 20),
                Text(tr('Отмена', 'Бекор кардан'), style: TextStyle(color: AppColors.ruby, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Красная точка, которая плавно мигает во время записи.
class _BlinkDot extends StatefulWidget {
  const _BlinkDot();

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: AppColors.ruby, shape: BoxShape.circle),
      ),
    );
  }
}

/// Большая синяя кнопка отправки записи с пульсирующими кругами.
class _PulseSendButton extends StatefulWidget {
  const _PulseSendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  State<_PulseSendButton> createState() => _PulseSendButtonState();
}

class _PulseSendButtonState extends State<_PulseSendButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              width: 46 + 14 * _c.value,
              height: 46 + 14 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.28 * (1 - _c.value)),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.deep],
                ),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

String _lastSeenText(DateTime seen) {
  String two(int n) => n.toString().padLeft(2, '0');
  final t = seen.toUtc().add(const Duration(hours: 5));
  final now = DateTime.now().toUtc().add(const Duration(hours: 5));
  final hm = '${two(t.hour)}:${two(t.minute)}';
  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay(t, now)) return '${tr('был(а) сегодня в', 'охирин бор имрӯз соати')} $hm';
  if (sameDay(t, now.subtract(const Duration(days: 1)))) {
    return '${tr('был(а) вчера в', 'охирин бор дирӯз соати')} $hm';
  }
  return '${tr('был(а)', 'охирин бор')} ${two(t.day)}.${two(t.month)}.${t.year} ${tr('в', 'соати')} $hm';
}

/// Запись о звонке в переписке: статус и время разговора.
class _CallEntry extends StatelessWidget {
  const _CallEntry({required this.value, required this.mine});

  /// Формат: 'answered|секунды', 'declined|0' или 'missed|0'.
  final String? value;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final parts = (value ?? 'missed|0').split('|');
    final status = parts[0];
    final secs = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final answered = status == 'answered';
    final title = switch (status) {
      'answered' => tr('Звонок', 'Занг'),
      'declined' => tr('Звонок отклонён', 'Занг рад шуд'),
      _ => tr('Пропущенный звонок', 'Занги нарасида'),
    };
    final sub = answered
        ? '${tr('Время разговора', 'Вақти суҳбат')} ${_callDuration(secs)}'
        : tr('Без ответа', 'Бе ҷавоб');
    final color = answered ? const Color(0xFF1FA653) : AppColors.ruby;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.15)),
          child: Icon(answered ? Icons.call_rounded : Icons.call_missed_rounded, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

String _callDuration(int secs) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  final s = secs % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}
