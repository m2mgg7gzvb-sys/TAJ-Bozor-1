import 'package:supabase_flutter/supabase_flutter.dart';

/// Черновик новой заявки: поля title, description, price, city, address.
/// Хранится в базе (listing_drafts), один черновик на пользователя.
class ListingDraft {
  static String? get _me => Supabase.instance.client.auth.currentUser?.id;

  static Future<Map<String, dynamic>?> load() async {
    final me = _me;
    if (me == null) return null;
    try {
      final row = await Supabase.instance.client
          .from('listing_drafts')
          .select('data')
          .eq('user_id', me)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row['data'] as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> save(Map<String, dynamic> data) async {
    final me = _me;
    if (me == null) return false;
    try {
      await Supabase.instance.client.from('listing_drafts').upsert({
        'user_id': me,
        'data': data,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
