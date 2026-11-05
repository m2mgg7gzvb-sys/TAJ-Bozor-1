import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'callback_sheet.dart';
import 'chat_screen.dart';
import 'create_listing_screen.dart';
import 'fallback_photo.dart';
import 'favorites_store.dart';
import 'listing_card.dart';
import 'listing_utils.dart';
import 'nav_state.dart';
import 'photo_viewer.dart';
import 'lang_store.dart';
import 'listing_reports.dart';
import 'theme.dart';
import 'user_profile_screen.dart';

/// Страница объявления: галерея, цена, кнопки связи, описание, продавец,
/// похожие объявления и другие объявления продавца.
class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.item});

  final Map<String, dynamic> item;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final _pageCtrl = PageController();
  int _page = 0;
  bool _descOpen = false;
  Map<String, dynamic>? _seller;
  late final Future<List<Map<String, dynamic>>> _similar = _loadSimilar();
  late final Future<List<Map<String, dynamic>>> _sellerItems = _loadSellerItems();

  // Копия объявления: после правки владельцем обновляем её из базы.
  late Map<String, dynamic> _item = Map<String, dynamic>.from(widget.item);
  int? _views;

  String get _id => _item['id'] as String;
  String? get _userId => _item['user_id'] as String?;
  bool get _isOwner => _userId != null && _userId == Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadSeller();
    _countView();
  }

  /// Засчитывает просмотр (не для владельца) и получает общее число просмотров.
  Future<void> _countView() async {
    try {
      final n = await Supabase.instance.client.rpc('bump_listing_view', params: {'lid': _id});
      if (mounted) setState(() => _views = (n as num?)?.toInt());
    } catch (_) {
      // Без счётчика экран работает как раньше
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateListingScreen(listing: _item)),
    );
    if (saved != true) return;
    try {
      final row = await Supabase.instance.client
          .from('listings')
          .select(listingSelect)
          .eq('id', _id)
          .single();
      if (mounted) setState(() => _item = Map<String, dynamic>.from(row));
    } catch (_) {
      // Если не удалось обновить, покажем старые данные до следующего открытия.
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSeller() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('name, city, phone')
          .eq('id', uid)
          .maybeSingle();
      if (mounted && row != null) setState(() => _seller = Map<String, dynamic>.from(row));
    } catch (_) {
      // Без продавца страница всё равно работает.
    }
  }

  Future<List<Map<String, dynamic>>> _loadSimilar() async {
    final cat = _item['category_id'];
    var query = Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .neq('id', _id);
    if (cat != null) query = query.eq('category_id', cat);
    final rows = await query.order('created_at', ascending: false).limit(10);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadSellerItems() async {
    final uid = _userId;
    if (uid == null) return [];
    final rows = await Supabase.instance.client
        .from('listings')
        .select(listingSelect)
        .eq('status', 'active')
        .eq('user_id', uid)
        .neq('id', _id)
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Записываем событие (звонок, поделились) для статистики. Ошибка не мешает пользователю.
  Future<void> _logEvent(String kind) async {
    try {
      await Supabase.instance.client.from('listing_events').insert({'listing_id': _id, 'kind': kind});
    } catch (_) {}
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// «Написать»: открывает переписку с продавцом. Гостя отправляем входить.
  Future<void> _write() async {
    final me = Supabase.instance.client.auth.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (me == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      tabIndex.value = loginTabIndex;
      return;
    }
    if (_userId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось найти продавца')));
      return;
    }
    if (_userId == me.id) {
      messenger.showSnackBar(const SnackBar(content: Text('Это ваше объявление')));
      return;
    }
    try {
      final id = await findOrCreateConversation(kind: 'listing', listingId: _id, sellerId: _userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, title: _item['title'] as String),
        ),
      );
    } on PostgrestException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось открыть переписку: ${e.message}')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Не удалось открыть переписку')));
    }
  }

  static const _carLabels = {
    'year': 'Год выпуска',
    'mileage_km': 'Пробег',
    'condition': 'Состояние',
    'body_type': 'Тип кузова',
    'fuel': 'Топливо',
    'engine_volume': 'Объём двигателя',
    'gearbox': 'Коробка',
    'drive': 'Привод',
    'steering': 'Руль',
    'model': 'Модель',
    'generation': 'Поколение',
    'trim': 'Комплектация',
    'color': 'Цвет',
    'vin': 'VIN',
  };

  /// Строки характеристик авто (только заполненные поля).
  List<MapEntry<String, String>> _carRows() {
    final raw = _item['details'];
    if (raw is! Map) return [];
    final d = Map<String, dynamic>.from(raw);
    final rows = <MapEntry<String, String>>[];
    for (final key in _carLabels.keys) {
      final v = d[key];
      if (v == null || '$v'.trim().isEmpty) continue;
      var text = '$v';
      if (key == 'mileage_km') text = '$text км';
      if (key == 'engine_volume') text = '$text л';
      if (key == 'vin') text = _maskVin(text);
      rows.add(MapEntry(_carLabels[key]!, text));
    }
    return rows;
  }

  /// VIN показываем частично: первые 3 и последние 4 символа.
  String _maskVin(String vin) {
    if (vin.length <= 7) return vin;
    return '${vin.substring(0, 3)}••••••••${vin.substring(vin.length - 4)}';
  }

  /// Открывает адрес продавца в Яндекс Картах.
  Future<void> _openMap() async {
    final address = _item['address'] as String?;
    if (address == null || address.isEmpty) {
      _toast('Адрес пока не указан');
      return;
    }
    final url = Uri.parse('https://yandex.ru/maps/?text=${Uri.encodeQueryComponent(address)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _call() async {
    final phone = _seller?['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      _toast('Номер продавца пока не указан');
      return;
    }
    unawaited(_logEvent('call'));
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!ok && mounted) _toast('Не удалось открыть звонок');
  }

  void _share() {
    unawaited(_logEvent('share'));
    final text = '${_item['title']} — ${priceText(_item)}\nTAJ Bozor';
    Share.share(text);
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: 'https://tajbozor.netlify.app/?listing=$_id'));
    if (mounted) _toast('Ссылка скопирована');
  }

  String _date() {
    final raw = _item['created_at'] as String?;
    if (raw == null) return '';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return 'Опубликовано ${two(d.day)}.${two(d.month)}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final photos = photoUrls(item);
    final city = item['city'] as String?;
    final address = item['address'] as String?;
    final description = item['description'] as String?;
    final sellerName = (_seller?['name'] as String?)?.trim();
    final sellerCity = (_seller?['city'] as String?) ?? city;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Объявление', 'Эълон')),
        actions: [
          if (!_isOwner && Supabase.instance.client.auth.currentUser != null)
            IconButton(
              tooltip: 'Пожаловаться',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showReportDialog(context, _id),
            ),
          if (_isOwner)
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_rounded),
              onPressed: _edit,
            ),
          IconButton(
            tooltip: 'Поделиться',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Скопировать ссылку',
            icon: const Icon(Icons.link_rounded),
            onPressed: _copyLink,
          ),
          ValueListenableBuilder<Set<String>>(
            valueListenable: FavoritesStore.ids,
            builder: (context, favIds, _) {
              final fav = favIds.contains(_id);
              return IconButton(
                tooltip: 'В избранное',
                icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? AppColors.ruby : null),
                onPressed: () async {
                  final error = await FavoritesStore.toggle(_id);
                  if (error != null && mounted) _toast(error);
                },
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Галерея
          SizedBox(
            height: 300,
            child: Stack(
              children: [
                photos.isEmpty
                    ? SizedBox.expand(child: FallbackPhoto(item: item))
                    : PageView.builder(
                        controller: _pageCtrl,
                        itemCount: photos.length,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PhotoViewer(photos: photos, initialIndex: i)),
                          ),
                          child: Image.network(
                            photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => FallbackPhoto(item: item),
                          ),
                        ),
                      ),
                if (photos.length > 1)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_page + 1} из ${photos.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Цена и название
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        priceText(item),
                        style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (_views != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 20, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Text(
                            '$_views',
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(item['title'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                if (item['listing_no'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SelectableText(
                      'Объявление №${item['listing_no']} · укажите номер в поддержке',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (city != null && city.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(city, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    if (_date().isNotEmpty)
                      Text(_date(), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),

                const SizedBox(height: 18),

                if (address != null && address.isNotEmpty) ...[
                  Text(address, style: const TextStyle(fontSize: 15)),
                  TextButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(tr('Показать на карте', 'Дар харита нишон додан')),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                ],

                if (_isOwner && item['status'] == 'moderation') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF4DE), borderRadius: BorderRadius.circular(14)),
                    child: const Text('На проверке · до 30 минут',
                        style: TextStyle(color: Color(0xFF9A5B00), fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 14),
                ],
                // Кнопки связи: заказать звонок сверху, ниже «Позвонить» и «Написать»
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2D8CFF)),
                  onPressed: () => showCallbackSheet(context, listingId: _id),
                  child: Text(tr('Заказать звонок', 'Занг сафориш додан')),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF13C15A)),
                        onPressed: _call,
                        child: Text(tr('Позвонить', 'Занг задан')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        onPressed: _write,
                        child: Text(tr('Написать', 'Навиштан')),
                      ),
                    ),
                  ],
                ),

                // Продавец
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _item['user_id'] == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: _item['user_id'] as String),
                            ),
                          ),
                  child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardDecoration(radius: 18),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.mint,
                        child: Icon(Icons.person_rounded, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (sellerName != null && sellerName.isNotEmpty) ? sellerName : 'Частное лицо',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            _SellerRating(sellerId: _item['user_id'] as String?),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),

                // Про автомобиль
                if (_carRows().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tr('Про автомобиль', 'Дар бораи мошин'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: cardDecoration(radius: 16),
                    child: Column(
                      children: [
                        for (final r in _carRows())
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(r.key, style: const TextStyle(color: AppColors.muted)),
                                ),
                                Text(r.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Описание
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tr('Описание', 'Тавсиф'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: _descOpen ? null : 6,
                    overflow: _descOpen ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                  if (description.length > 280)
                    TextButton(
                      onPressed: () => setState(() => _descOpen = !_descOpen),
                      child: Text(_descOpen ? 'Свернуть' : 'Читать полностью'),
                    ),
                ],

                // Похожие объявления
                const SizedBox(height: 24),
                _Strip(future: _similar),

                // Другие объявления продавца
                const SizedBox(height: 24),
                _Strip(future: _sellerItems),

                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),

    );
  }
}

/// Горизонтальная прокрутка карточек. Пустой список не показывает ничего.
class _Strip extends StatelessWidget {
  const _Strip({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 230, child: Center(child: CircularProgressIndicator()));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Text(tr('Пока ничего нет', 'Ҳоло ҳеҷ чиз нест'), style: TextStyle(color: AppColors.muted));
        }
        return SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: 170, child: ListingCard(item: items[i])),
          ),
        );
      },
    );
  }
}

/// Строка «Отзывы» с пятью звёздами: закрашены по средней оценке продавца.
class _SellerRating extends StatelessWidget {
  const _SellerRating({required this.sellerId});

  final String? sellerId;

  Future<List<Map<String, dynamic>>> _load() async {
    if (sellerId == null) return [];
    final rows = await Supabase.instance.client
        .from('reviews')
        .select('rating')
        .eq('reviewed_id', sellerId!);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _load(),
      builder: (_, snap) {
        final rows = snap.data ?? const <Map<String, dynamic>>[];
        final sum = rows.fold<int>(0, (s, r) => s + ((r['rating'] as num?)?.toInt() ?? 0));
        final filled = rows.isEmpty ? 0 : (sum / rows.length).round();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Отзывы', 'Шарҳҳо'), style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(width: 6),
            for (var i = 1; i <= 5; i++)
              Icon(
                i <= filled ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: i <= filled ? const Color(0xFFF2B600) : AppColors.muted,
              ),
          ],
        );
      },
    );
  }
}
