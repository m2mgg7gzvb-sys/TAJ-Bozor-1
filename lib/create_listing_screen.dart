import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

/// Подача объявления: категория, описание, цена, город и до 5 фото.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key});

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Душанбе');
  final List<XFile> _photos = [];

  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  int? _categoryId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, name_ru')
          .order('id');
      if (mounted) setState(() => _categories = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      // Список останется пустым, пользователь увидит подсказку.
    } finally {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
    if (picked.isEmpty) return;
    setState(() => _photos.addAll(picked.take(5 - _photos.length)));
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _saving = false;
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _fail('Войдите, чтобы подать объявление');
    if (_categoryId == null) return _fail('Выберите категорию');
    if (title.length < 3) return _fail('Название — от 3 символов');
    if (price == null || price < 0) return _fail('Укажите цену числом');
    if (_photos.isEmpty) return _fail('Добавьте хотя бы одно фото');

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = Supabase.instance.client;
      final row = await db
          .from('listings')
          .insert({
            'user_id': user.id,
            'category_id': _categoryId,
            'title': title,
            'description': _descCtrl.text.trim(),
            'price': price,
            'currency': 'TJS',
            'city': _cityCtrl.text.trim(),
            'status': 'active',
          })
          .select('id')
          .single();
      final listingId = row['id'] as String;

      for (var i = 0; i < _photos.length; i++) {
        final bytes = await _photos[i].readAsBytes();
        final path = '${user.id}/$listingId/$i.jpg';
        await db.storage.from('listing-photos').uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        await db.from('listing_images').insert({
          'listing_id': listingId,
          'path': path,
          'position': i,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _fail('Не удалось опубликовать. Проверьте сеть и попробуйте снова');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подать объявление')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text('Категория', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_loadingCategories)
            const LinearProgressIndicator()
          else
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              hint: const Text('Выберите категорию'),
              items: [
                for (final c in _categories)
                  DropdownMenuItem<int>(
                    value: c['id'] as int,
                    child: Text(c['name_ru'] as String),
                  ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'Название объявления'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Цена, TJS'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(hintText: 'Город'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: 'Описание'),
          ),
          const SizedBox(height: 8),
          const Text('Фото (до 5)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Chip(
                  avatar: const Icon(Icons.image_outlined, size: 18),
                  label: Text('Фото ${i + 1}'),
                  onDeleted: () => setState(() => _photos.removeAt(i)),
                ),
              if (_photos.length < 5)
                ActionChip(
                  avatar: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Добавить'),
                  onPressed: _pickPhotos,
                ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Опубликовать'),
          ),
        ],
      ),
    );
  }
}
