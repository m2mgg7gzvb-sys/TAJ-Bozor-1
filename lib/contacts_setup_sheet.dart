import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'green_button.dart';
import 'seller_contacts.dart';
import 'theme.dart';

const _shownPrefix = 'contacts_setup_shown_';

/// Один раз после входа показываем окно «Контакты», если контактов ещё нет.
/// Отметку «уже показано» ставим при любом закрытии, чтобы не надоедать.
Future<void> maybeShowContactsSetup(BuildContext context) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || user.isAnonymous) return;
  final uid = user.id;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('$_shownPrefix$uid') == true) return;

    final own = await SellerContacts.own(uid);
    if (!own.isEmpty) {
      await prefs.setBool('$_shownPrefix$uid', true);
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ContactsSetupSheet(uid: uid),
    );
    await prefs.setBool('$_shownPrefix$uid', true);
  } catch (_) {
    // Окно необязательное: при ошибке просто не показываем
  }
}

class _ContactsSetupSheet extends StatefulWidget {
  const _ContactsSetupSheet({required this.uid});

  final String uid;

  @override
  State<_ContactsSetupSheet> createState() => _ContactsSetupSheetState();
}

class _ContactsSetupSheetState extends State<_ContactsSetupSheet> {
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _telegram = TextEditingController();
  bool _showContacts = true;
  bool _verifiedBySms = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefill();
  }

  /// Подставляем номер из профиля (в том числе подтверждённый SMS) и уже сохранённые контакты.
  Future<void> _loadPrefill() async {
    final db = Supabase.instance.client;
    try {
      final profile = await db
          .from('profiles')
          .select('phone, phone_verified')
          .eq('id', widget.uid)
          .maybeSingle();
      final own = await SellerContacts.own(widget.uid);
      if (!mounted) return;
      setState(() {
        _phone.text = (profile?['phone'] as String?) ?? '';
        _verifiedBySms = profile?['phone_verified'] == true;
        _whatsapp.text = own.whatsapp ?? _phone.text;
        _telegram.text = own.telegram == null ? '' : '@${own.telegram}';
      });
    } catch (_) {
      // Оставляем поля пустыми
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _whatsapp.dispose();
    _telegram.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final phoneRaw = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (phoneRaw.isNotEmpty && !RegExp(r'^\+992\d{9}$').hasMatch(phoneRaw)) {
      setState(() => _error = 'Прямой номер в формате +992 и 9 цифр');
      return;
    }
    final waRaw = _whatsapp.text.trim();
    final waNum = waRaw.isEmpty ? null : SellerContacts.normalizeWhatsapp(waRaw);
    if (waRaw.isNotEmpty && waNum == null) {
      setState(() => _error = 'WhatsApp: номер в формате +992 (9 цифр) или +7 (10 цифр)');
      return;
    }
    final tgRaw = _telegram.text.trim();
    final tgNick = tgRaw.isEmpty ? null : SellerContacts.normalizeTelegram(tgRaw);
    if (tgRaw.isNotEmpty && tgNick == null) {
      setState(() => _error = 'Telegram: ник от 5 символов, латиница, цифры и _');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      // Прямой номер хранится в профиле: по нему объявления показывают телефон продавца
      await db.from('profiles').update({'phone': phoneRaw.isEmpty ? null : phoneRaw}).eq('id', widget.uid);
      await SellerContacts.save(
        widget.uid,
        whatsapp: waNum,
        telegram: tgNick,
        show: _showContacts,
      );
      if (mounted) Navigator.of(context).pop(true);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Контакты для покупателей',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Эти контакты увидят покупатели в ваших объявлениях и в чате.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Прямой номер',
                hintText: '+992900000000',
                helperText: _verifiedBySms ? 'Подтверждён по SMS' : null,
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+992900000000 или +79001234567',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset('assets/icons/whatsapp_logo.png', width: 22, height: 22),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telegram,
              decoration: InputDecoration(
                labelText: 'Telegram',
                hintText: '@ваш_ник',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset('assets/icons/telegram_logo.png', width: 22, height: 22),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _showContacts,
              onChanged: (v) => setState(() => _showContacts = v),
              title: const Text('Показывать покупателям в чате'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: AppColors.ruby)),
            ],
            const SizedBox(height: 16),
            GreenButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Сохранить'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Позже'),
            ),
          ],
        ),
      ),
    );
  }
}
