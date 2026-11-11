import 'laptop_catalog.dart';
import 'phone_catalog.dart';

/// Характеристика: ключ в details, подпись и варианты выбора.
class TechField {
  const TechField(this.key, this.label, this.options);
  final String key;
  final String label;
  final List<String> options;
}

/// Характеристики для подкатегорий «Электроника» (id подкатегории → поля).
/// Телефоны (1) и ноутбуки (5) описаны отдельно.
const techSpecs = <int, List<TechField>>{
  2: [
    // Аудио и видео
    TechField('brand', 'Производитель', ['Sony', 'Samsung', 'JBL', 'Bose', 'Apple', 'Xiaomi', 'Другой']),
    TechField('type', 'Тип', ['Наушники', 'Колонки', 'Телевизор', 'Проектор', 'Другое']),
    TechField('connection', 'Подключение', ['Проводное', 'Беспроводное']),
  ],
  3: [
    // Товары для компьютера
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
  ],
  4: [
    // Игры, приставки и программы
    TechField('platform', 'Платформа', ['PlayStation', 'Xbox', 'Nintendo', 'PC', 'Другая']),
    TechField('type', 'Тип', ['Игра', 'Приставка', 'Геймпад / аксессуар', 'Программа']),
  ],
  6: [
    // Настольные компьютеры
    TechField('brand', 'Производитель', ['Apple', 'ASUS', 'DELL', 'HP', 'Lenovo', 'MSI', 'Acer', 'Другой']),
    TechField('type', 'Тип', ['Системный блок', 'Моноблок', 'Игровой ПК', 'Мини-ПК']),
    TechField('cpu', 'Процессор', laptopCpus),
    TechField('ram', 'Оперативная память', laptopRam),
    TechField('storage', 'Накопитель', laptopStorage),
  ],
  7: [
    // Фототехника
    TechField('brand', 'Производитель', ['Canon', 'Nikon', 'Sony', 'Fujifilm', 'GoPro', 'DJI', 'Другой']),
    TechField('type', 'Тип', ['Зеркальная', 'Беззеркальная', 'Компактная', 'Экшн-камера', 'Объектив', 'Дрон', 'Аксессуары']),
  ],
  8: [
    // Планшеты и электронные книги
    TechField('brand', 'Производитель', ['Apple', 'Samsung', 'Xiaomi', 'Huawei', 'Lenovo', 'Honor', 'Другой']),
    TechField('diagonal', 'Диагональ экрана, дюйм', ['Менее 8', '8 — 9.9', '10 — 10.9', '11 и более']),
    TechField('memory', 'Память', phoneMemory),
  ],
  9: [
    // Оргтехника и расходники
    TechField('brand', 'Производитель', ['HP', 'Canon', 'Epson', 'Brother', 'Xerox', 'Kyocera', 'Другой']),
    TechField('type', 'Тип', ['Принтер', 'МФУ', 'Сканер', 'Картриджи', 'Бумага', 'Другое']),
  ],
};

/// Общие для всех подкатегорий поля.
const techSharedFields = [
  TechField('condition', 'Состояние', phoneConditions),
  TechField('seller_type', 'Продавец', phoneSellers),
];

/// Все ключи, которые могут встретиться в details таких объявлений.
const techKeys = [
  'brand', 'type', 'connection', 'platform', 'cpu', 'ram', 'storage', 'diagonal', 'memory',
  'condition', 'seller_type',
];

bool isTechSubcategory(int? id) => id != null && techSpecs.containsKey(id);

List<TechField> techFieldsFor(int id) => [...?techSpecs[id], ...techSharedFields];
