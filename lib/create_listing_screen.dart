import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';

const _bodyTypes = ['Седан', 'Хэтчбек', 'Универсал', 'Кроссовер', 'Внедорожник', 'Купе', 'Кабриолет', 'Минивэн', 'Пикап'];
const _fuels = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/бензин'];
const _gearboxes = ['Автомат', 'Механика', 'Робот', 'Вариатор'];
const _drives = ['Передний', 'Задний', 'Полный'];
const _wheels = ['Левый', 'Правый'];
const _conditions = ['Новый', 'С пробегом'];

/// Подача объявления: категория, описание, цена, город, фото и для авто — характеристики.
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
  final _addressCtrl = TextEditingController();
  final List<XFile> _photos = [];

  // Характеристики автомобиля
  final _yearCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _engineCtrl = TextEditingController();
  final _generationCtrl = TextEditingController();
  final _trimCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  String? _bodyType;
  String? _fuel;
  String? _gearbox;
  String? _drive;
  String? _wheel;
  String? _condition;

  List<Map<String, dynamic>> _categories = [];
  bool _loadingCategories = true;
  int? _categoryId;
  bool _saving = false;
  String? _error;

  bool get _isAuto => _categories.any((c) => c['id'] == _categoryId && c['slug'] == 'auto');

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _cityCtrl,
      _addressCtrl,
      _yearCtrl,
      _mileageCtrl,
      _engineCtrl,
      _generationCtrl,
      _trimCtrl,
      _colorCtrl,
      _vinCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, slug, name_ru')
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

  /// Характеристики авто: заполненные поля, пустые не сохраняем.
  Map<String, dynamic> _carDetails() {
    final m = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) m[key] = value.trim();
    }

    put('year', _yearCtrl.text);
    put('mileage_km', _mileageCtrl.text);
    put('body_type', _bodyType);
    put('fuel', _fuel);
    put('engine_volume', _engineCtrl.text);
    put('gearbox', _gearbox);
    put('drive', _drive);
    put('steering', _wheel);
    put('condition', _condition);
    put('generation', _generationCtrl.text);
    put('trim', _trimCtrl.text);
    put('color', _colorCtrl.text);
    put('vin', _vinCtrl.text.toUpperCase());
    return m;
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
    if (_isAuto) {
      final yearText = _yearCtrl.text.trim();
      final year = int.tryParse(yearText);
      if (yearText.isNotEmpty && (year == null || year < 1950 || year > 2030)) {
        return _fail('Год выпуска — число от 1950 до 2030');
      }
      final vin = _vinCtrl.text.trim();
      if (vin.isNotEmpty && vin.length != 17) return _fail('VIN — ровно 17 символов');
    }

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
            'address': _addressCtrl.text.trim(),
            'details': _isAuto ? _carDetails() : null,
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

  Widget _field(TextEditingController c, String hint, {TextInputType? type, int? maxLength}) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLength: maxLength,
      decoration: InputDecoration(hintText: hint, counterText: ''),
    );
  }

  Widget _drop(String hint, String? value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$hint-$value'),
      initialValue: value,
      hint: Text(hint),
      items: [for (final i in items) DropdownMenuItem<String>(value: i, child: Text(i))],
      onChanged: (v) => setState(() => onChanged(v)),
    );
  }

  /// Блок «Про автомобиль»: показывается, когда выбрана категория «Авто».
  List<Widget> _carSection() {
    return [
      const SizedBox(height: 20),
      const Text('Про автомобиль', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      const SizedBox(height: 4),
      const Text(
        'Чем подробнее, тем больше доверия и звонков. Все поля, кроме VIN, необязательные.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
      ),
      const SizedBox(height: 12),
      _field(_yearCtrl, 'Год выпуска, например 2019', type: TextInputType.number, maxLength: 4),
      const SizedBox(height: 12),
      _field(_mileageCtrl, 'Пробег, км', type: TextInputType.number),
      const SizedBox(height: 12),
      _drop('Состояние', _condition, _conditions, (v) => _condition = v),
      const SizedBox(height: 12),
      _drop('Тип кузова', _bodyType, _bodyTypes, (v) => _bodyType = v),
      const SizedBox(height: 12),
      _drop('Топливо', _fuel, _fuels, (v) => _fuel = v),
      const SizedBox(height: 12),
      _field(_engineCtrl, 'Объём двигателя, л, например 2.0', type: const TextInputType.numberWithOptions(decimal: true)),
      const SizedBox(height: 12),
      _drop('Коробка передач', _gearbox, _gearboxes, (v) => _gearbox = v),
      const SizedBox(height: 12),
      _drop('Привод', _drive, _drives, (v) => _drive = v),
      const SizedBox(height: 12),
      _drop('Руль', _wheel, _wheels, (v) => _wheel = v),
      const SizedBox(height: 12),
      _field(_colorCtrl, 'Цвет'),
      const SizedBox(height: 12),
      _field(_generationCtrl, 'Поколение, например G82'),
      const SizedBox(height: 12),
      _field(_trimCtrl, 'Комплектация или модификация'),
      const SizedBox(height: 12),
      _field(_vinCtrl, 'VIN, 17 символов (не показывается полностью)', maxLength: 17),
    ];
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
            controller: _addressCtrl,
            decoration: const InputDecoration(hintText: 'Адрес (улица, дом) для карты'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: 'Описание'),
          ),
          if (_isAuto) ..._carSection(),
          const SizedBox(height: 16),
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
