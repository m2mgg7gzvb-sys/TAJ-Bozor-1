import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'glass_widgets.dart';
import 'theme.dart';
import 'user_profile_screen.dart';
import 'green_button.dart';

/// Нижнее окно отзыва: аватар и имя продавца, объявление, звёзды и поле для текста.
/// Возвращает true, если отзыв сохранён.
Future<bool> showReviewSheet(
  BuildContext context, {
  required String sellerId,
  required String conversationId,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GlassSheet(
      child: _ReviewSheet(sellerId: sellerId, conversationId: conversationId),
    ),
  );
  return sent == true;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.sellerId, required this.conversationId});

  final String sellerId;
  final String conversationId;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  final _db = Supabase.instance.client;
  final _ctrl = TextEditingController();
  int _rating = 5;
  bool _sending = false;
  String? _name;
  String? _avatarUrl;
  String? _listingTitle;
  final _photos = <XFile>[];

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final prof = await _db
          .from('profiles')
          .select('name, avatar_url')
          .eq('id', widget.sellerId)
          .maybeSingle();
      final conv = await _db
          .from('conversations')
          .select('listing_id')
          .eq('id', widget.conversationId)
          .maybeSingle();
      String? title;
      final listingId = conv?['listing_id'] as String?;
      if (listingId != null) {
        final l = await _db.from('listings').select('title').eq('id', listingId).maybeSingle();
        title = l?['title'] as String?;
      }
      if (!mounted) return;
      setState(() {
        _name = prof?['name'] as String?;
        _avatarUrl = prof?['avatar_url'] as String?;
        _listingTitle = title;
      });
    } catch (_) {
      // Без имени и объявления окно всё равно работает
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty || !mounted) return;
    setState(() => _photos.addAll(picked.take(5 - _photos.length)));
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final me = _db.auth.currentUser!.id;
      final row = await _db
          .from('reviews')
          .upsert(
            {
              'reviewed_id': widget.sellerId,
              'author_id': me,
              'rating': _rating,
              'body': _ctrl.text.trim(),
            },
            onConflict: 'reviewed_id,author_id',
          )
          .select('id')
          .single();
      final reviewId = row['id'] as String;
      if (_photos.isNotEmpty) {
        final paths = <String>[];
        for (var i = 0; i < _photos.length; i++) {
          final bytes = await _photos[i].readAsBytes();
          final path = '$me/$reviewId/$i.jpg';
          await _db.storage.from('review-photos').uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
              );
          paths.add(path);
        }
        await _db.from('reviews').update({'photos': paths}).eq('id', reviewId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить отзыв')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = (_name ?? '').trim();
    final name = trimmed.isEmpty ? 'Продавец' : trimmed;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(name: name, url: _avatarUrl, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (_listingTitle != null && _listingTitle!.isNotEmpty)
                      Text(
                        _listingTitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: const Color(0xFFF2B600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Напишите отзыв о продавце',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: FutureBuilder<Uint8List>(
                        future: _photos[i].readAsBytes(),
                        builder: (_, snap) => snap.hasData
                            ? Image.memory(snap.data!, width: 64, height: 64, fit: BoxFit.cover)
                            : const SizedBox(width: 64, height: 64),
                      ),
                    ),
                  ),
                if (_photos.length < 5)
                  GestureDetector(
                    onTap: _pickPhotos,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GreenButton(
            onPressed: _sending ? null : _send,
            height: 50,
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Отправить отзыв'),
          ),
        ],
      ),
    );
  }
}
