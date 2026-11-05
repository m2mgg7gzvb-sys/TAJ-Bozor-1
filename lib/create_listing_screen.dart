import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'car_catalog.dart';
import 'city_store.dart';
import 'confirm_delete.dart';
import 'map_picker.dart';
import 'theme.dart';

const _bodyTypes = ['Седан', 'Хэтчбек', 'Универсал', 'Кроссовер', 'Внедорожник', 'Купе', 'Кабриолет', 'Минивэн', 'Пикап'];
const _fuels = ['Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/бензин'];
const _gearboxes = ['Автомат', 'Механика', 'Робот', 'Вариатор'];
const _drives = ['Передний', 'Задний', 'Полный'];
const _wheels = ['Левый', 'Правый'];
const _conditions = ['Новый', 'С пробегом'];

/// Справочник авто — см. car_catalog.dart.
const _carCatalog = carCatalog;
final _carYears = carYears;

/// Подача объявления: категория, описание, цена, город, фото и для авто — характеристики.
class CreateListingScreen extends StatefulWidget {
  const CreateListingScreen({super.key, this.listing});

  /// Если передано — экран открывается для правки уже опубликованного объявления.
  final Map<String, dynamic>? listing;

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  double? _lat;
  double? _lng;
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
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
  int _days = 14;
  String? _error;

  bool get _isAuto => _categories.any((c) => c['id'] == _categoryId && c['slug'] == 'auto');

  @override
  void initState() {
    super.initState();
    if (widget.listing != null) _prefill();
    _loadCategories();
    _loadPhone();
  }

  /// Подставляем телефон из профиля, чтобы не вводить его каждый раз.
  Future<void> _loadPhone() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    if (me == null) return;
    try {
      final p = await Supabase.instance.client.from('profiles').select('phone').eq('id', me).maybeSingle();
      final phone = p?['phone'] as String?;
      // В поле храним только 9 цифр без +992: из «+992929990835» получаем «929990835».
      if (mounted && phone != null && _phoneCtrl.text.isEmpty) {
        var digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.startsWith('992')) digits = digits.substring(3);
        _phoneCtrl.text = digits.length > 9 ? digits.substring(0, 9) : digits;
      }
    } catch (_) {
      // Телефон введут вручную
    }
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descCtrl,
      _priceCtrl,
      _cityCtrl,
      _addressCtrl,
      _phoneCtrl,
      _brandCtrl,
      _modelCtrl,
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

  /// Режим правки: заполняем поля уже опубликованного объявления.
  void _prefill() {
    final l = widget.listing!;
    final price = num.tryParse('${l['price']}');
    _titleCtrl.text = (l['title'] as String?) ?? '';
    _descCtrl.text = (l['description'] as String?) ?? '';
    _priceCtrl.text = price == null ? '' : (price % 1 == 0 ? price.toStringAsFixed(0) : '$price');
    _cityCtrl.text = (l['city'] as String?) ?? '';
    _addressCtrl.text = (l['address'] as String?) ?? '';
    _lat = (l['lat'] as num?)?.toDouble();
    _lng = (l['lng'] as num?)?.toDouble();
    _categoryId = l['category_id'] as int?;
    final d = Map<String, dynamic>.from((l['details'] as Map?) ?? {});
    String s(String k) => '${d[k] ?? ''}';
    _brandCtrl.text = s('brand');
    _modelCtrl.text = s('model');
    _yearCtrl.text = s('year');
    _mileageCtrl.text = s('mileage_km');
    _engineCtrl.text = s('engine_volume');
    _generationCtrl.text = s('generation');
    _trimCtrl.text = s('trim');
    _colorCtrl.text = s('color');
    _vinCtrl.text = s('vin');
    _bodyType = d['body_type'] as String?;
    _fuel = d['fuel'] as String?;
    _gearbox = d['gearbox'] as String?;
    _drive = d['drive'] as String?;
    _wheel = d['steering'] as String?;
    _condition = d['condition'] as String?;
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

  String _daysWord(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'дней';
    if (m10 == 1) return 'день';
    if (m10 >= 2 && m10 <= 4) return 'дня';
    return 'дней';
  }

  /// Название авто как на Авито: «Марка Модель объём КПП, год».
  String _autoTitle() {
    const gearShort = {'Автомат': 'AT', 'Механика': 'MT', 'Робот': 'RT', 'Вариатор': 'CVT'};
    final head = [
      _brandCtrl.text.trim(),
      _modelCtrl.text.trim(),
      _engineCtrl.text.trim(),
      if (_gearbox != null) gearShort[_gearbox] ?? '',
    ].where((e) => e.isNotEmpty).join(' ');
    final year = _yearCtrl.text.trim();
    if (head.isEmpty) return year;
    return year.isEmpty ? head : '$head, $year';
  }

  /// Выпадающий список, который не падает, если сохранённого значения нет в списке.
  Widget _pick(String hint, String current, List<String> items, ValueChanged<String> onChanged) {
    return _drop(hint, items.contains(current) ? current : null, items, (v) => onChanged(v ?? ''));
  }

  /// Открывает карту и сохраняет выбранную точку.
  Future<void> _pickPoint() async {
    final initial = (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null;
    final p = await pickMapPoint(context, initial: initial, city: _cityCtrl.text);
    if (p == null || !mounted) return;
    setState(() {
      _lat = p.latitude;
      _lng = p.longitude;
    });
  }

  /// Характеристики авто: заполненные поля, пустые не сохраняем.
  Map<String, dynamic> _carDetails() {
    final m = <String, dynamic>{};
    void put(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) m[key] = value.trim();
    }

    put('brand', _brandCtrl.text);
    put('model', _modelCtrl.text);
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

  /// Удаление: объявление скрывается (статус «hidden»), данные не теряются.
  Future<void> _delete() async {
    final id = widget.listing!['id'] as String;
    final ok = await confirmDeleteByTyping(context);
    if (ok != true) return;
    try {
      await Supabase.instance.client.from('listings').update({'status': 'hidden'}).eq('id', id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      _fail('Не удалось удалить. Попробуйте снова');
    }
  }

  Future<void> _submit() async {
    final title = _isAuto ? _autoTitle() : _titleCtrl.text.trim();
    final price = num.tryParse(_priceCtrl.text.trim().replaceAll(',', '.'));
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return _fail('Войдите, чтобы подать объявление');
    if (_categoryId == null) return _fail('Выберите категорию');
    if (title.length < 3) return _fail('Название — от 3 символов');
    if (price == null || price < 0) return _fail('Укажите цену числом');
    if (_cityCtrl.text.trim().isEmpty) return _fail('Выберите город');
    if (_phoneCtrl.text.length != 9) return _fail('Номер телефона: +992 и 9 цифр');
    if (widget.listing == null && _photos.isEmpty) return _fail('Добавьте хотя бы одно фото');
    if (_isAuto) {
      if (_brandCtrl.text.isEmpty) return _fail('Выберите марку автомобиля');
      if (_modelCtrl.text.isEmpty) return _fail('Выберите модель');
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
      // Телефон сохраняем в профиле: по нему с объявлением связываются покупатели.
      await db.from('profiles').update({'phone': '+992${_phoneCtrl.text}'}).eq('id', user.id);
      final editing = widget.listing;
      if (editing != null) {
        // Правка: фото не меняем, обновляем только текстовые поля и характеристики.
        await db.from('listings').update({
          'status': 'moderation',
          'category_id': _categoryId,
          'title': title,
          'description': _descCtrl.text.trim(),
          'price': price,
          'city': _cityCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'lat': _lat,
          'lng': _lng,
          'details': _isAuto ? _carDetails() : null,
        }).eq('id', editing['id'] as String);
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
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
            'lat': _lat,
            'lng': _lng,
            'details': _isAuto ? _carDetails() : null,
            'status': 'moderation',
            'expires_at': DateTime.now().toUtc().add(Duration(days: _days)).toIso8601String(),
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

  Widget _field(TextEditingController c, String hint, {TextInputType? type, int? maxLength, ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      keyboardType: type,
      maxLength: maxLength,
      onChanged: onChanged,
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
        'Марка и модель обязательны, название объявления соберётся из них. Остальное можно не заполнять.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
      ),
      const SizedBox(height: 12),
      _pick('Марка', _brandCtrl.text, _carCatalog.keys.toList(), (v) {
        _brandCtrl.text = v;
        _modelCtrl.text = '';
        _generationCtrl.text = '';
      }),
      const SizedBox(height: 12),
      _pick(
        'Модель',
        _modelCtrl.text,
        _carCatalog[_brandCtrl.text]?.keys.toList() ?? const [],
        (v) {
          _modelCtrl.text = v;
          _generationCtrl.text = '';
        },
      ),
      if ((_carCatalog[_brandCtrl.text]?[_modelCtrl.text] ?? const <String>[]).isNotEmpty) ...[
        const SizedBox(height: 12),
        _pick(
          'Поколение',
          _generationCtrl.text,
          _carCatalog[_brandCtrl.text]![_modelCtrl.text]!,
          (v) => _generationCtrl.text = v,
        ),
        if (_generationCtrl.text.isNotEmpty)
          carGenerationPhoto(_brandCtrl.text, _modelCtrl.text, _generationCtrl.text),
      ],
      const SizedBox(height: 12),
      _pick('Год выпуска', _yearCtrl.text, _carYears, (v) => _yearCtrl.text = v),
      const SizedBox(height: 12),
      Text(
        'Название: ${_autoTitle()}',
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 12),
      _field(_mileageCtrl, 'Пробег, км', type: TextInputType.number),
      const SizedBox(height: 12),
      _drop('Состояние', _condition, _conditions, (v) => _condition = v),
      const SizedBox(height: 12),
      _drop('Тип кузова', _bodyType, _bodyTypes, (v) => _bodyType = v),
      const SizedBox(height: 12),
      _drop('Топливо', _fuel, _fuels, (v) => _fuel = v),
      const SizedBox(height: 12),
      _field(
        _engineCtrl,
        'Объём двигателя, л, например 2.0',
        type: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),
      _drop('Коробка передач', _gearbox, _gearboxes, (v) => _gearbox = v),
      const SizedBox(height: 12),
      _drop('Привод', _drive, _drives, (v) => _drive = v),
      const SizedBox(height: 12),
      _drop('Руль', _wheel, _wheels, (v) => _wheel = v),
      const SizedBox(height: 12),
      _field(_colorCtrl, 'Цвет'),
      const SizedBox(height: 12),
      _field(_trimCtrl, 'Комплектация или модификация'),
      const SizedBox(height: 12),
      _field(_vinCtrl, 'VIN, 17 символов (не показывается полностью)', maxLength: 17),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listing == null ? 'Подать объявление' : 'Редактировать объявление'),
      ),
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
          if (!_isAuto) ...[
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(hintText: 'Название объявления'),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: const InputDecoration(
              hintText: '9 цифр, например 901234567',
              prefixText: '+992 ',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Цена, TJS'),
          ),
          const SizedBox(height: 12),
          _drop(
            'Город',
            _cityCtrl.text.isEmpty ? null : _cityCtrl.text,
            [
              ...tajCities,
              if (_cityCtrl.text.isNotEmpty && !tajCities.contains(_cityCtrl.text)) _cityCtrl.text,
            ],
            (v) => _cityCtrl.text = v ?? '',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(hintText: 'Адрес (улица, дом) для карты'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickPoint,
            icon: const Icon(Icons.location_on_outlined),
            label: Text(_lat == null ? 'Указать точку на карте' : 'Точка выбрана · изменить'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: 'Описание'),
          ),
          if (_isAuto) ..._carSection(),
          if (widget.listing == null) ...[
          const SizedBox(height: 16),
          Text(
            'Срок объявления: $_days ${_daysWord(_days)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: _days.toDouble(),
            min: 7,
            max: 30,
            divisions: 23,
            label: '$_days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          const Text(
            'От 7 до 30 дней. По истечении срока объявление снимается с публикации.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
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
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ],
          if (widget.listing != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _saving ? null : _delete,
              child: Text('Удалить объявление', style: TextStyle(color: Colors.red.shade700)),
            ),
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
                : Text(widget.listing == null ? 'Опубликовать' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}
