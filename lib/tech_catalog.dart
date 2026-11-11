import 'car_catalog.dart';
import 'laptop_catalog.dart';
import 'phone_catalog.dart';

/// Характеристика: ключ в details, подпись и варианты выбора.
class TechField {
  const TechField(this.key, this.label, this.options, {this.inForm = true});
  final String key;
  final String label;
  final List<String> options;

  /// false — поле уже заполняется в форме (блок «Про автомобиль»), здесь только для фильтра.
  final bool inForm;
}

/// Набор полей для одной подкатегории («sub:N») или категории без подкатегорий («cat:N»).
class TechSpec {
  const TechSpec(this.fields, {this.shared = true});
  final List<TechField> fields;

  /// Добавлять общие «Состояние» и «Продавец».
  final bool shared;
}

const techSharedFields = [
  TechField('condition', 'Состояние', phoneConditions),
  TechField('seller_type', 'Продавец', phoneSellers),
];

final carBrandList = carCatalog.keys.toList();
final motoBrandList = motoCatalog.keys.toList();

/// Общие поля Авто: заполняются в блоке «Про автомобиль», здесь только фильтр.
final _autoCommon = [
  TechField('condition', 'Состояние', carConditions, inForm: false),
  TechField('seller_type', 'Продавец', carSellerTypes, inForm: false),
];

final techSpecs = <String, TechSpec>{
  // ── Электроника ─────────────────────────────────────────────
  'sub:2': TechSpec([
    TechField('brand', 'Производитель', ['Sony', 'Samsung', 'JBL', 'Bose', 'Apple', 'Xiaomi', 'Другой']),
    TechField('type', 'Тип', ['Наушники', 'Колонки', 'Телевизор', 'Проектор', 'Другое']),
    TechField('connection', 'Подключение', ['Проводное', 'Беспроводное']),
  ]),
  'sub:3': TechSpec([
    TechField('brand', 'Производитель', ['Intel', 'AMD', 'NVIDIA', 'ASUS', 'MSI', 'Gigabyte', 'Kingston', 'Corsair', 'Другой']),
    TechField('type', 'Тип', [
      'Процессор',
      'Видеокарта',
      'Оперативная память',
      'Материнская плата',
      'SSD / HDD',
      'Блок питания',
      'Корпус',
      'Другое',
    ]),
  ]),
  'sub:4': TechSpec([
    TechField('platform', 'Платформа', ['PlayStation', 'Xbox', 'Nintendo', 'PC', 'Другая']),
    TechField('type', 'Тип', ['Игра', 'Приставка', 'Геймпад / аксессуар', 'Программа']),
  ]),
  'sub:6': TechSpec([
    TechField('brand', 'Производитель', ['Apple', 'ASUS', 'DELL', 'HP', 'Lenovo', 'MSI', 'Acer', 'Другой']),
    TechField('type', 'Тип', ['Системный блок', 'Моноблок', 'Игровой ПК', 'Мини-ПК']),
    TechField('cpu', 'Процессор', laptopCpus),
    TechField('ram', 'Оперативная память', laptopRam),
    TechField('storage', 'Накопитель', laptopStorage),
  ]),
  'sub:7': TechSpec([
    TechField('brand', 'Производитель', ['Canon', 'Nikon', 'Sony', 'Fujifilm', 'GoPro', 'DJI', 'Другой']),
    TechField('type', 'Тип', ['Зеркальная', 'Беззеркальная', 'Компактная', 'Экшн-камера', 'Объектив', 'Дрон', 'Аксессуары']),
  ]),
  'sub:8': TechSpec([
    TechField('brand', 'Производитель', ['Apple', 'Samsung', 'Xiaomi', 'Huawei', 'Lenovo', 'Honor', 'Другой']),
    TechField('diagonal', 'Диагональ экрана, дюйм', ['Менее 8', '8 — 9.9', '10 — 10.9', '11 и более']),
    TechField('memory', 'Память', phoneMemory),
  ]),
  'sub:9': TechSpec([
    TechField('brand', 'Производитель', ['HP', 'Canon', 'Epson', 'Brother', 'Xerox', 'Kyocera', 'Другой']),
    TechField('type', 'Тип', ['Принтер', 'МФУ', 'Сканер', 'Картриджи', 'Бумага', 'Другое']),
  ]),

  // ── Авто (подкатегории) ─────────────────────────────────────
  'sub:11': TechSpec([
    TechField('brand', 'Производитель', carBrandList, inForm: false),
    TechField('body_type', 'Кузов', carBodyTypes, inForm: false),
    TechField('fuel', 'Топливо', carFuels, inForm: false),
    TechField('gearbox', 'Коробка передач', carGearboxes, inForm: false),
    TechField('drive', 'Привод', carDrives, inForm: false),
    ..._autoCommon,
  ], shared: false),
  'sub:12': TechSpec([
    TechField('brand', 'Производитель', carBrandList, inForm: false),
    TechField('body_type', 'Кузов', carBodyTypes, inForm: false),
    TechField('fuel', 'Топливо', carFuels, inForm: false),
    TechField('gearbox', 'Коробка передач', carGearboxes, inForm: false),
    ..._autoCommon,
  ], shared: false),
  'sub:13': TechSpec([
    TechField('brand', 'Производитель', carBrandList, inForm: false),
    TechField('country', 'Страна бренда', carCountries, inForm: false),
    TechField('drive', 'Привод', carDrives, inForm: false),
    ..._autoCommon,
  ], shared: false),
  'sub:14': TechSpec([
    TechField('brand', 'Производитель', ['MAN', 'Mercedes-Benz', 'Volvo', 'Scania', 'KAMAZ', 'MAZ', 'ГАЗ', 'Isuzu', 'Другой'], inForm: false),
    TechField('truck_type', 'Тип', ['Грузовик', 'Самосвал', 'Фургон', 'Тягач', 'Спецтехника', 'Прицеп']),
    TechField('fuel', 'Топливо', carFuels, inForm: false),
    ..._autoCommon,
  ], shared: false),
  'sub:15': TechSpec([
    TechField('brand', 'Производитель', motoBrandList, inForm: false),
    TechField('moto_type', 'Тип', ['Спорт', 'Круизер', 'Эндуро', 'Скутер', 'Мопед', 'Кросс']),
    TechField('engine_cc', 'Объём двигателя', ['До 125 см³', '125–400 см³', '400–800 см³', '800 см³ и больше']),
    ..._autoCommon,
  ], shared: false),
  'sub:16': TechSpec([
    TechField('rent_class', 'Класс', ['Эконом', 'Комфорт', 'Бизнес', 'Премиум']),
    TechField('gearbox', 'Коробка передач', carGearboxes, inForm: false),
    TechField('with_driver', 'С водителем', carYesNo),
  ], shared: false),
  'sub:17': TechSpec([
    TechField('equipment_type', 'Тип техники', ['Экскаватор', 'Бульдозер', 'Погрузчик', 'Автокран', 'Трактор', 'Манипулятор', 'Другое']),
    TechField('operator', 'Оператор', ['С оператором', 'Без оператора']),
  ], shared: false),
  'sub:18': TechSpec([
    TechField('brand', 'Производитель', carBrandList, inForm: false),
    TechField('part_type', 'Тип запчасти', ['Двигатель', 'Кузов', 'Тормоза', 'Подвеска', 'Электрика', 'Шины и диски', 'Салон', 'Другое']),
    ..._autoCommon,
  ], shared: false),

  // ── Категории без подкатегорий ──────────────────────────────
  'cat:2': TechSpec([
    TechField('deal', 'Сделка', ['Продажа', 'Аренда']),
    TechField('property_type', 'Тип недвижимости', ['Квартира', 'Дом', 'Комната', 'Участок', 'Коммерческая', 'Гараж']),
    TechField('rooms', 'Комнат', ['Студия', '1', '2', '3', '4', '5+']),
    TechField('seller_type', 'Продавец', ['Собственник', 'Агент', 'Застройщик']),
  ], shared: false),
  'cat:4': TechSpec([
    TechField('type', 'Тип', ['Мебель', 'Бытовая техника', 'Декор', 'Текстиль', 'Сад и огород', 'Ремонт и строительство', 'Другое']),
    TechField('room', 'Комната', ['Гостиная', 'Спальня', 'Кухня', 'Ванная', 'Прихожая', 'Сад', 'Другое']),
  ]),
  'cat:5': TechSpec([
    TechField('service_type', 'Вид услуги', ['Ремонт', 'Строительство', 'Красота', 'Обучение', 'Доставка', 'Перевозки', 'IT и дизайн', 'Другое']),
    TechField('format', 'Формат', ['На дому', 'У исполнителя', 'С выездом']),
  ], shared: false),
  'cat:6': TechSpec([
    TechField('job_type', 'Тип работы', ['Полная занятость', 'Частичная', 'Подработка', 'Удалённо', 'Сменный график']),
    TechField('field', 'Сфера', ['Продажи', 'Водитель', 'Строительство', 'Общепит', 'IT', 'Образование', 'Медицина', 'Другое']),
  ], shared: false),
  'cat:7': TechSpec([
    TechField('brand', 'Производитель', ['Bosch', 'Brembo', 'Mann', 'Castrol', 'Michelin', 'Другой']),
    TechField('part_type', 'Тип', ['Шины и диски', 'Аккумуляторы', 'Инструменты', 'Для ремонта', 'Другое']),
  ]),
  'cat:8': TechSpec([
    TechField('kind', 'Вид', ['Одежда', 'Обувь', 'Аксессуары', 'Сумки', 'Украшения']),
    TechField('gender', 'Для кого', ['Мужское', 'Женское', 'Детское', 'Унисекс']),
    TechField('size', 'Размер', ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'Другой']),
  ]),
  'cat:9': TechSpec([
    TechField('deal', 'Сделка', ['Продажа', 'Аренда', 'Партнёрство']),
    TechField('type', 'Тип', ['Оборудование', 'Транспорт', 'Торговое', 'Производство', 'Готовый бизнес', 'Другое']),
  ], shared: false),
  'cat:10': TechSpec([
    TechField('stay_type', 'Тип жилья', ['Квартира', 'Дом', 'Гостевой дом', 'Отель', 'Комната']),
    TechField('guests', 'Гостей', ['1–2', '3–4', '5–6', '7 и больше']),
  ], shared: false),
  'cat:11': TechSpec([
    TechField('kind', 'Вид', ['Спорт и отдых', 'Туризм', 'Музыка', 'Коллекции', 'Книги', 'Настолки', 'Рыбалка и охота', 'Другое']),
  ]),
};

/// Все ключи, которые могут встретиться в details таких объявлений.
final techAllKeys = <String>{
  for (final s in techSpecs.values) for (final f in s.fields) f.key,
  for (final f in techSharedFields) f.key,
};

String techKey(int categoryId, int? subcategoryId) =>
    subcategoryId != null ? 'sub:$subcategoryId' : 'cat:$categoryId';

/// Есть ли для этой категории/подкатегории свой набор характеристик.
bool hasTech(int categoryId, int? subcategoryId) => techSpecs.containsKey(techKey(categoryId, subcategoryId));

/// Поля фильтра и формы для категории/подкатегории (с общими, если нужны).
List<TechField> techFieldsFor(int categoryId, int? subcategoryId) {
  final spec = techSpecs[techKey(categoryId, subcategoryId)];
  if (spec == null) return const [];
  final extra = spec.shared
      ? techSharedFields.where((s) => spec.fields.every((f) => f.key != s.key))
      : const <TechField>[];
  return [...spec.fields, ...extra];
}
