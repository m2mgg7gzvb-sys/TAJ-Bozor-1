import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:url_launcher/url_launcher.dart';

import 'chat_screen.dart';
import 'wave_background.dart';
import 'listing_card.dart';
import 'user_reviews_screen.dart';
import 'listing_utils.dart';
import 'copy_id.dart';
import 'block_store.dart';
import 'follow_button.dart';
import 'lang_store.dart';
import 'theme.dart';
import 'user_complaints.dart';
import 'green_button.dart';

/// Кружок с буквой имени или фото пользователя.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.name, this.url, this.radius = 18});

  final String name;
  final String? url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final hasPhoto = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      backgroundImage: hasPhoto ? NetworkImage(url!) : null,
      child: hasPhoto
          ? null
          : Text(
              letter,
              style: TextStyle(
                color: AppColors.surface,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.9,
              ),
            ),
    );
  }
}

class _UserData {
  const _UserData({
    required this.profile,
    required this.listings,
    required this.reviews,
    this.viewerIsAdmin = false,
    this.viewerIsSuper = false,
  });

  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> listings;
  final List<Map<String, dynamic>> reviews;
  final bool viewerIsAdmin;
  final bool viewerIsSuper;

  int get activeCount => listings.where((l) => l['status'] == 'active').length;
  int get closedCount => listings.where((l) => l['status'] != 'active').length;
  double? get avgRating {
    if (reviews.isEmpty) return null;
    final sum = reviews.fold<int>(0, (s, r) => s + ((r['rating'] as num?)?.toInt() ?? 0));
    return sum / reviews.length;
  }
}

/// Публичный профиль пользователя: объявления, статистика и отзывы.
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _db = Supabase.instance.client;
  late Future<_UserData> _future = _load();

  @override
  void initState() {
    super.initState();
    BlockStore.load();
  }

  String get _me => _db.auth.currentUser?.id ?? '';

  Future<_UserData> _load() async {
    final profile = await _db
        .from('profiles')
        .select('name, city, phone, avatar_url, public_id, is_admin, is_verified, is_blocked')
        .eq('id', widget.userId)
        .maybeSingle();
    var viewerIsAdmin = false;
    var viewerIsSuper = false;
    if (_me.isNotEmpty) {
      final me = await _db.from('profiles').select('is_admin, is_super_admin').eq('id', _me).maybeSingle();
      viewerIsAdmin = me?['is_admin'] == true;
      viewerIsSuper = me?['is_super_admin'] == true;
    }
    final listings = List<Map<String, dynamic>>.from(await _db
        .from('listings')
        .select('$listingSelect, status')
        .eq('user_id', widget.userId)
        .order('created_at', ascending: false));
    final reviews = List<Map<String, dynamic>>.from(await _db
        .from('reviews')
        .select('rating, body, created_at')
        .eq('reviewed_id', widget.userId)
        .order('created_at', ascending: false));
    return _UserData(
      profile: profile ?? {},
      listings: listings,
      reviews: reviews,
      viewerIsAdmin: viewerIsAdmin,
      viewerIsSuper: viewerIsSuper,
    );
  }

  /// Действие админа через защищённую функцию в базе; после — перечитываем профиль.
  Future<void> _adminCall(String fn, Map<String, dynamic> params, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _db.rpc(fn, params: params);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(res is int ? '$ok: $res' : ok),
      ));
      setState(() => _future = _load());
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(tr('Действие не выполнено', 'Амал иҷро нашуд'))));
    }
  }

  Widget _adminPanel(_UserData d) {
    final uid = widget.userId;
    final blocked = d.profile['is_blocked'] == true;
    final verified = d.profile['is_verified'] == true;
    final admin = d.profile['is_admin'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Управление (админ)', 'Идоракунӣ (админ)'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 10),
          GreenButton.icon(
            height: 46,
            onPressed: () => _adminCall(
              'admin_set_blocked',
              {'p_user': uid, 'p_blocked': !blocked},
              blocked ? tr('Разблокирован', 'Кушода шуд') : tr('Заблокирован', 'Баста шуд'),
            ),
            icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
            label: Text(blocked ? tr('Разблокировать', 'Кушодан') : tr('Заблокировать', 'Баст кардан')),
          ),
          const SizedBox(height: 8),
          GreenButton.icon(
            height: 46,
            onPressed: d.viewerIsSuper
                ? () => _adminCall(
                      'admin_set_admin',
                      {'p_user': uid, 'p_admin': !admin},
                      admin ? tr('Права админа сняты', 'Ҳуқуқҳои админ гирифта шуд') : tr('Выдан админ', 'Админ таъин шуд'),
                    )
                : null,
            icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
            label: Text(admin ? tr('Снять админа', 'Гирифтани админ') : tr('Дать админа', 'Таъин кардани админ')),
          ),
          const SizedBox(height: 8),
          GreenButton.icon(
            height: 46,
            onPressed: () => _adminCall(
              'admin_set_verified',
              {'p_user': uid, 'p_verified': !verified},
              verified ? tr('Бейдж снят', 'Нишона гирифта шуд') : tr('Бейдж выдан', 'Нишона дода шуд'),
            ),
            icon: const Icon(Icons.verified_outlined, size: 18),
            label: Text(verified ? tr('Снять бейдж «Проверено»', 'Гирифтани нишонаи «Тасдиқшуда»') : tr('Выдать бейдж «Проверено»', 'Додани нишонаи «Тасдиқшуда»')),
          ),
          const SizedBox(height: 8),
          GreenButton.icon(
            height: 46,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(tr('Скрыть все объявления?', 'Ҳамаи эълонҳоро пинҳон кунем?')),
                  content: Text(tr('Все активные объявления этого пользователя станут скрытыми.', 'Ҳамаи эълонҳои фаъоли ин корбар пинҳон мешаванд.')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Отмена', 'Бекор кардан'))),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Скрыть', 'Пинҳон кардан'))),
                  ],
                ),
              );
              if (ok == true) {
                await _adminCall('admin_hide_user_listings', {'p_user': uid}, tr('Скрыто объявлений', 'Эълон пинҳон шуд'));
              }
            },
            icon: const Icon(Icons.visibility_off_outlined, size: 18),
            label: Text(tr('Скрыть все объявления', 'Пинҳон кардани ҳамаи эълонҳо')),
          ),
          const SizedBox(height: 8),
          GreenButton.icon(
            height: 46,
            onPressed: () => _adminCall(
              'admin_unhide_user_listings',
              {'p_user': uid},
              tr('Возвращено объявлений', 'Эълон баргардонда шуд'),
            ),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(tr('Вернуть скрытые объявления', 'Баргардонидани эълонҳои пинҳон')),
          ),
        ],
      ),
    );
  }

  /// Звонок по телефону пользователя (как в объявлении).
  Future<void> _callSeller(String phone) async {
    final messenger = ScaffoldMessenger.of(context);
    if (phone.trim().isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Номер пока не указан', 'Рақам ҳанӯз нишон дода нашудааст'))));
      return;
    }
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
    if (!ok && mounted) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Не удалось открыть звонок', 'Кушодани занг муяссар нашуд'))));
    }
  }

  /// Открывает личную переписку с этим пользователем.
  Future<void> _write(String title) async {
    try {
      final id = await findOrCreateConversation(kind: 'listing', sellerId: widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(conversationId: id, title: title)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Не удалось открыть переписку', 'Кушодани мактубот муяссар нашуд'))),
      );
    }
  }

  Widget _stat(String value, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return WaveBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tr('Профиль пользователя', 'Профили корбар')),
        actions: [
          if (_me.isNotEmpty && _me != widget.userId)
            IconButton(
              tooltip: tr('Пожаловаться', 'Шикоят кардан'),
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => showUserComplaintDialog(context, widget.userId),
            ),
          if (_me.isNotEmpty && _me != widget.userId)
            ValueListenableBuilder<Set<String>>(
              valueListenable: BlockStore.ids,
              builder: (context, ids, _) {
                final blocked = ids.contains(widget.userId);
                return TextButton(
                  onPressed: () async {
                    final nowBlocked = await BlockStore.toggle(widget.userId);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(nowBlocked
                          ? tr('Пользователь заблокирован: его объявления скрыты из поиска', 'Корбар баста шуд: эълонҳояш аз ҷустуҷӯ пинҳон шуданд')
                          : tr('Блокировка снята', 'Баст бекор шуд')),
                    ));
                  },
                  child: Text(blocked ? tr('Разблокировать', 'Кушодан') : tr('Заблокировать', 'Баст кардан')),
                );
              },
            ),
        ],
      ),
      body: FutureBuilder<_UserData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data == null) {
            return Center(child: Text(tr('Не удалось загрузить профиль', 'Боргирии профил муяссар нашуд')));
          }
          final d = snap.data!;
          final name = (d.profile['name'] as String?)?.trim();
          final displayName = (name == null || name.isEmpty) ? tr('Пользователь', 'Корбар') : name;
          final city = d.profile['city'] as String?;
          final avg = d.avgRating;
          final canReview = _me.isNotEmpty && _me != widget.userId;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (canReview) ...[
                  FollowButton(sellerId: widget.userId),
                  const SizedBox(height: 12),
                ],
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: displayName,
                        url: d.profile['avatar_url'] as String?,
                        radius: 36,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(displayName,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                ),
                                if (d.profile['is_admin'] == true) ...[
                                  const SizedBox(width: 6),
                                  Image.asset('assets/admin_badge.png', height: 56),
                                ],
                                if (d.profile['is_verified'] == true) ...[
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
                                ],
                              ],
                            ),
                            if (city != null && city.isNotEmpty)
                              Text(city, style: TextStyle(color: AppColors.muted)),
                            if (d.profile['public_id'] != null)
                              CopyIdLine(label: tr('ID профиля:', 'ID-и профил:'), id: '${d.profile['public_id']}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canReview) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GreenButton.icon(
                          onPressed: () => _write(displayName),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: Text(tr('Написать', 'Навиштан')),
                          height: 50,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                          onPressed: () => _callSeller('${d.profile['phone'] ?? ''}'),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: Text(tr('Позвонить', 'Занг задан')),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    _stat('${d.activeCount}', tr('Активных', 'Фаъол')),
                    const SizedBox(width: 10),
                    _stat('${d.closedCount}', tr('Завершённых', 'Анҷомёфта')),
                  ],
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => UserReviewsScreen(userId: widget.userId)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Text(tr('Отзывы', 'Бознигариҳо'), style: TextStyle(fontWeight: FontWeight.w700)),
                        const Spacer(),
                        SellerStars(rating: {'avg': avg ?? 0, 'count': d.reviews.length}),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
                if (d.viewerIsAdmin && widget.userId != _me) ...[
                  const SizedBox(height: 16),
                  _adminPanel(d),
                ],
                const SizedBox(height: 22),
                Text(tr('Объявления', 'Эълонҳо'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                if (d.activeCount == 0)
                  Text(tr('Активных объявлений нет', 'Эълонҳои фаъол нест'), style: TextStyle(color: AppColors.muted))
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.66,
                    children: [
                      for (final l in d.listings.where((l) => l['status'] == 'active'))
                        ListingCard(item: l),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    ));
  }
}
