import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Поднимает объявление в топ (не чаще раза в 24 часа).
Future<void> bumpListing(BuildContext context, String listingId) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await Supabase.instance.client.rpc('bump_listing', params: {'p_id': listingId});
    messenger.showSnackBar(const SnackBar(content: Text('Объявление поднято в топ')));
  } catch (e) {
    final text = '$e';
    messenger.showSnackBar(SnackBar(
      content: Text(text.contains('too_soon')
          ? 'Поднять можно не чаще раза в 24 часа'
          : 'Не удалось поднять объявление'),
    ));
  }
}
