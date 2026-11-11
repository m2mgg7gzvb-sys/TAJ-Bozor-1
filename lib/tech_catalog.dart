import 'car_catalog.dart';
import 'laptop_catalog.dart';
import 'phone_catalog.dart';

/// Характеристика: ключ в details, подпись и варианты выбора.
class TechField {
  const TechField(this.key, this.label, this.options, {this.inForm = true, this.range = false});
  final String key;
  final String label;
  final List<String> options;

  /// false — поле уже заполняется в форме (блок «Про автомобиль»), здесь только для фильтра.
  final bool inForm;

  /// true — числовое поле: в форме ввод числа, в фильтре диапазон «от / до».
  final bool range;
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

const realEstateTypes = [
  'Квартиры',
  'Комнаты',
  'Дома, дачи, коттеджи',
  'Земельные участки',
  'Гаражи и машиноместа',
  'Коммерческая недвижимость',
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
  // Недвижимость: базовый набор (тип и сделка) и свой набор на каждый тип.
  'cat:2': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду', 'Посуточно']),
    TechField('new_or_secondary', 'Новостройки и вторичка', ['Вторичка', 'Новостройка']),
    TechField('rooms', 'Количество комнат', ['Студия', '1', '2', '3', '4', '5+']),
  ], shared: false),
  'cat:2:Квартиры': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду', 'Посуточно']),
    TechField('new_or_secondary', 'Новостройки и вторичка', ['Вторичка', 'Новостройка']),
    TechField('rooms', 'Количество комнат', ['Студия', '1', '2', '3', '4', '5+']),
    TechField('area', 'Общая площадь, м²', [], range: true),
    TechField('kitchen_area', 'Площадь кухни, м²', [], range: true),
    TechField('floors_total', 'Этажей в доме', [], range: true),
    TechField('price_m2', 'Цена за м², TJS', [], range: true, inForm: false),
    TechField('mortgage', 'Можно в ипотеке', ['Да']),
    TechField('profitable', 'Выгодно', ['Да']),
    TechField('verified', 'Проверенные квартиры', ['Данные Росреестра и сроки сдачи ЖК']),
    TechField('reviews', 'Есть отзывы о доме', ['Да']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
    TechField('floor_pos', 'Этаж', ['Не первый', 'Не последний', 'Только последний']),
    TechField('housing', 'Тип жилья', ['Квартиры', 'Апартаменты']),
    TechField('room_type', 'Тип комнат', ['Изолированные', 'Смежные']),
    TechField('balcony', 'Балкон или лоджия', ['Балкон', 'Лоджия']),
    TechField('bathroom', 'Санузел', ['Совмещённый', 'Раздельный']),
    TechField('finish', 'Отделка', ['Без отделки', 'Предчистовая', 'Чистовая']),
    TechField('repair', 'Ремонт', ['С ремонтом', 'Без ремонта']),
    TechField('ceiling', 'Высота потолков, м', ['от 2,7', 'от 3', 'от 3,5']),
    TechField('sale_method', 'Способ продажи', ['Прямая', 'Альтернативная']),
    TechField('hide', 'Скрыть объявления', ['О продаже доли', 'О продаже с аукциона']),
    TechField('house_type', 'Тип дома', ['Кирпичный', 'Панельный', 'Монолитный', 'Блочный', 'Деревянный']),
    TechField('elevator', 'Лифт', ['Пассажирский', 'Грузовой']),
    TechField('with_photo', 'Объявления с фото', ['Да']),
  ], shared: false),
  'cat:2:Комнаты': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду']),
    TechField('area', 'Площадь, м²', [], range: true),
    TechField('room_share', 'Тип комнаты', ['Изолированная', 'Смежная']),
    TechField('rooms_count', 'Комнат в квартире', ['1', '2', '3', '4+']),
    TechField('floor_pos', 'Этаж', ['Не первый', 'Не последний', 'Только последний']),
    TechField('bathroom', 'Санузел', ['Совмещённый', 'Раздельный']),
    TechField('repair', 'Ремонт', ['С ремонтом', 'Без ремонта']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
  ], shared: false),
  'cat:2:Дома, дачи, коттеджи': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду']),
    TechField('area', 'Площадь дома, м²', [], range: true),
    TechField('year_built', 'Год постройки', [], range: true),
    TechField('house_kind', 'Тип', ['Дом', 'Дача', 'Коттедж', 'Таунхаус']),
    TechField('material', 'Материал стен', ['Кирпич', 'Газоблок', 'Дерево', 'Панель', 'Монолит', 'Другой']),
    TechField('floors', 'Этажей', ['1', '2', '3', '4+']),
    TechField('land', 'Участок', ['Есть', 'Нет']),
    TechField('repair', 'Ремонт', ['С ремонтом', 'Без ремонта']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
  ], shared: false),
  'cat:2:Земельные участки': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду']),
    TechField('area', 'Площадь, сот.', [], range: true),
    TechField('land_purpose', 'Назначение', ['ИЖС', 'ЛПХ', 'Дачное', 'Коммерческое', 'Сельхоз']),
    TechField('communications', 'Коммуникации', ['Газ', 'Электричество', 'Вода', 'Канализация']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
  ], shared: false),
  'cat:2:Гаражи и машиноместа': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду']),
    TechField('garage_type', 'Тип', ['Гараж', 'Машиноместо', 'Бокс']),
    TechField('heating', 'Отопление', ['Есть', 'Нет']),
    TechField('pit', 'Смотровая яма', ['Есть', 'Нет']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
  ], shared: false),
  'cat:2:Коммерческая недвижимость': TechSpec([
    TechField('property_type', 'Тип недвижимости', realEstateTypes),
    TechField('deal', 'Сделка', ['Купить', 'В аренду']),
    TechField('area', 'Площадь, м²', [], range: true),
    TechField('commercial_type', 'Тип', ['Офис', 'Магазин', 'Склад', 'Производство', 'Общепит', 'Свободного назначения']),
    TechField('entrance', 'Отдельный вход', ['Есть', 'Нет']),
    TechField('repair', 'Ремонт', ['С ремонтом', 'Без ремонта']),
    TechField('seller_type', 'Продавцы', ['Частные', 'Застройщики', 'Агентства']),
    TechField('contact', 'Способы связи', ['Звонки', 'Сообщения']),
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

String techKey(int categoryId, int? subcategoryId, [String? propertyType]) {
  if (subcategoryId != null) return 'sub:$subcategoryId';
  if (categoryId == 2 && propertyType != null && techSpecs.containsKey('cat:2:$propertyType')) {
    return 'cat:2:$propertyType';
  }
  return 'cat:$categoryId';
}

/// Есть ли для этой категории/подкатегории свой набор характеристик.
bool hasTech(int categoryId, int? subcategoryId) => techSpecs.containsKey(techKey(categoryId, subcategoryId));

/// Поля фильтра и формы. Для недвижимости набор зависит от выбранного типа.
List<TechField> techFieldsFor(int categoryId, int? subcategoryId, [String? propertyType]) {
  final spec = techSpecs[techKey(categoryId, subcategoryId, propertyType)];
  if (spec == null) return const [];
  final extra = spec.shared
      ? techSharedFields.where((s) => spec.fields.every((f) => f.key != s.key))
      : const <TechField>[];
  return [...spec.fields, ...extra];
}
