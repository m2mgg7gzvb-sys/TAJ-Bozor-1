import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'favorites_store.dart';
import 'my_listings_tab.dart';
import 'nav_state.dart';
import 'theme.dart';
import 'welcome_screen.dart';

/// Вкладка «Войти»: форма входа, если никто не вошёл, иначе профиль.
class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return const WelcomeScreen();
    return _ProfilePage(user: user);
  }
}

/// Данные профиля и счётчики для шапки.
class _ProfileData {
  const _ProfileData({this.name, this.city, this.phone, this.listingsCount = 0, this.isAdmin = false});

  final String? name;
  final String? city;
  final String? phone;
  final int listingsCount;
  final bool isAdmin;

  static const empty = _ProfileData();
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.user});

  final User user;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  late Future<_ProfileData> _data = _load();

  Future<_ProfileData> _load() async {
    final db = Supabase.instance.client;
    final uid = widget.user.id;
    final profile = await db
        .from('profiles')
        .select('name, city, phone, is_admin')
        .eq('id', uid)
        .maybeSingle();
    final listings = await db.from('listings').select('id').eq('user_id', uid);
    return _ProfileData(
      name: profile?['name'] as String?,
      city: profile?['city'] as String?,
      phone: profile?['phone'] as String?,
      listingsCount: listings.length,
      isAdmin: profile?['is_admin'] == true,
    );
  }

  void _reload() => setState(() => _data = _load());

  Future<void> _edit(_ProfileData d) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(user: widget.user, data: d),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = widget.user.isAnonymous;
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: FutureBuilder<_ProfileData>(
        future: _data,
        builder: (context, snap) {
          final d = snap.data ?? _ProfileData.empty;
          final hasName = d.name != null && d.name!.isNotEmpty;
          final name = isGuest ? 'Гость' : (hasName ? d.name! : 'Пользователь');
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _data;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileHeader(
                  name: name,
                  city: d.city,
                  phone: d.phone,
                  email: widget.user.email,
                  onEdit: isGuest ? null : () => _edit(d),
                ),
                const SizedBox(height: 14),
                ValueListenableBuilder<Set<String>>(
                  valueListenable: FavoritesStore.ids,
                  builder: (_, favIds, __) => Row(
                    children: [
                      Expanded(child: _Stat(value: '${d.listingsCount}', label: 'Объявления')),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(value: '${favIds.length}', label: 'Избранное')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isGuest) ...[
                  const _GuestBanner(),
                  const SizedBox(height: 16),
                ],
                _MenuCard(
                  children: [
                    _MenuTile(
                      icon: Icons.list_alt_rounded,
                      title: 'Мои объявления',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MyListingsTab()),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.favorite_border_rounded,
                      title: 'Избранное',
                      onTap: () => tabIndex.value = 1,
                    ),
                    _MenuTile(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Сообщения',
                      onTap: () => tabIndex.value = 3,
                    ),
                    if (!d.isAdmin)
                      _MenuTile(
                        icon: Icons.support_agent_rounded,
                        title: 'Поддержка',
                        onTap: () => tabIndex.value = 3,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Настройки',
                    style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                  ),
                ),
                _MenuCard(
                  children: [
                    if (!isGuest)
                      _MenuTile(
                        icon: Icons.edit_outlined,
                        title: 'Редактировать профиль',
                        onTap: () => _edit(d),
                      ),
                    _MenuTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Политика конфиденциальности',
                      onTap: () => _openText(context, 'Политика конфиденциальности'),
                    ),
                    _MenuTile(
                      icon: Icons.description_outlined,
                      title: 'Условия использования',
                      onTap: () => _openText(context, 'Условия использования'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isGuest)
                  OutlinedButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    child: const Text('Выйти'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _openText(BuildContext context, String title) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _TextPage(title: title)),
  );
}

/// Заглушка для юридических текстов. Текст появится после проверки юристом.
class _TextPage extends StatelessWidget {
  const _TextPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Текст появится здесь после проверки юристом.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.city,
    required this.phone,
    required this.email,
    this.onEdit,
  });

  final String name;
  final String? city;
  final String? phone;
  final String? email;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 20),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.primary,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    if (city != null && city!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(city!, style: const TextStyle(color: AppColors.muted)),
                    ],
                    if (phone != null && phone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(phone!, style: const TextStyle(color: AppColors.muted)),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      email ?? 'Вход без почты',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onEdit != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(onPressed: onEdit, child: const Text('Редактировать')),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: cardDecoration(radius: 16),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Форма редактирования имени, города и телефона продавца.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user, required this.data});

  final User user;
  final _ProfileData data;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.data.name ?? '');
  late final _city = TextEditingController(text: widget.data.city ?? '');
  late final _phone = TextEditingController(text: widget.data.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phone = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.isNotEmpty && !RegExp(r'^\+992\d{9}$').hasMatch(phone)) {
      setState(() => _error = 'Телефон в формате +992 и 9 цифр');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.from('profiles').upsert({
        'id': widget.user.id,
        'name': _name.text.trim(),
        'city': _city.text.trim(),
        'phone': phone.isEmpty ? null : phone,
      });
      if (mounted) Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      // Показываем причину из базы, чтобы её было видно и можно было исправить.
      if (mounted) setState(() => _error = 'Не удалось сохранить: ${e.message}');
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось сохранить. Попробуйте позже');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Редактировать профиль',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            decoration: const InputDecoration(labelText: 'Город'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Телефон', hintText: '+992900000000'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.ruby)),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Вы вошли как гость',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Зарегистрируйтесь по почте, чтобы не потерять объявления и избранное.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const _RegisterPage()),
            ),
            child: const Text('Зарегистрироваться'),
          ),
        ],
      ),
    );
  }
}

/// Экран регистрации поверх гостевого входа. Закрывается сам, когда пользователь подтвердил почту.
class _RegisterPage extends StatefulWidget {
  const _RegisterPage();

  @override
  State<_RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<_RegisterPage> {
  StreamSubscription<AuthState>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      final user = state.session?.user;
      if (user != null && !user.isAnonymous && mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const AuthScreen();
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: cardDecoration(radius: 18),
      child: Column(children: children),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
