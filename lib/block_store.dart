import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Заблокированные пользователи текущего аккаунта. Их объявления скрываются из поиска.
class BlockStore {
  BlockStore._();

  static final ids = ValueNotifier<Set<String>>({});

  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  static bool isBlocked(String userId) => ids.value.contains(userId);

  static Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      ids.value = {};
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      ids.value = {for (final r in rows) r['blocked_id'] as String};
    } catch (_) {
      // Без списка блокировок поиск работает как обычно.
    }
  }

  /// Блокирует или снимает блокировку. Возвращает true, если пользователь теперь заблокирован.
  static Future<bool> toggle(String userId) async {
    final uid = _uid;
    if (uid == null) return false;
    final next = Set<String>.from(ids.value);
    final removing = next.contains(userId);
    removing ? next.remove(userId) : next.add(userId);
    ids.value = next;
    try {
      if (removing) {
        await Supabase.instance.client
            .from('user_blocks')
            .delete()
            .eq('blocker_id', uid)
            .eq('blocked_id', userId);
      } else {
        await Supabase.instance.client.from('user_blocks').upsert({
          'blocker_id': uid,
          'blocked_id': userId,
        }, onConflict: 'blocker_id,blocked_id');
      }
    } catch (_) {
      await load();
      return isBlocked(userId);
    }
    return !removing;
  }
}
