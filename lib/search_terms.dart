/// Варианты написания для поиска: русское название бренда ищет и по латинице.
/// Например, «бмв» находит объявления, где написано «BMW».
/// Ключ — русское написание в нижнем регистре, значение — латиница, как пишут в объявлениях.
const _brandAliases = <String, String>{
  // Немецкие
  'бмв': 'bmw',
  'бмвэ': 'bmw',
  'мерс': 'mercedes',
  'мерседес': 'mercedes',
  'мерседас': 'mercedes',
  'мерседес-бенц': 'mercedes',
  'мерседес бенц': 'mercedes',
  'мерцедес': 'mercedes',
  'ауди': 'audi',
  'фольксваген': 'volkswagen',
  'фольцваген': 'volkswagen',
  'фольц': 'volkswagen',
  'опель': 'opel',
  'порше': 'porsche',
  'порш': 'porsche',
  'порщ': 'porsche',
  'порсче': 'porsche',
  // Японские
  'тойота': 'toyota',
  'тайота': 'toyota',
  'лексус': 'lexus',
  'хонда': 'honda',
  'хонда сивик': 'honda civic',
  'ниссан': 'nissan',
  'нисан': 'nissan',
  'мазда': 'mazda',
  'мицубиси': 'mitsubishi',
  'митсубиси': 'mitsubishi',
  'субару': 'subaru',
  'исузу': 'isuzu',
  'сузуки': 'suzuki',
  'инфинити': 'infiniti',
  // Корейские
  'киа': 'kia',
  'хендай': 'hyundai',
  'хюндай': 'hyundai',
  'хундай': 'hyundai',
  'генезис': 'genesis',
  'дженезис': 'genesis',
  // Американские
  'шевроле': 'chevrolet',
  'шевролет': 'chevrolet',
  'форд': 'ford',
  'джип': 'jeep',
  'додж': 'dodge',
  'крайслер': 'chrysler',
  'кадиллак': 'cadillac',
  'бьюик': 'buick',
  'тесла': 'tesla',
  // Французские
  'рено': 'renault',
  'пежо': 'peugeot',
  'ситроен': 'citroen',
  'дачия': 'dacia',
  'дача': 'dacia',
  // Итальянские
  'фиат': 'fiat',
  'феррари': 'ferrari',
  'ламборгини': 'lamborghini',
  'ламборджини': 'lamborghini',
  'мазерати': 'maserati',
  'альфа ромео': 'alfa romeo',
  // Британские
  'лэндровер': 'land rover',
  'ленд ровер': 'land rover',
  'ягуар': 'jaguar',
  'бентли': 'bentley',
  'роллс-ройс': 'rolls-royce',
  'роллс ройс': 'rolls-royce',
  'мини': 'mini',
  // Шведские
  'вольво': 'volvo',
  // Чешские и прочие европейские
  'шкода': 'skoda',
  'сеат': 'seat',
  // Китайские
  'чери': 'chery',
  'черри': 'chery',
  'джили': 'geely',
  'хавал': 'haval',
  'чанган': 'changan',
  'грейт волл': 'great wall',
  'бугатти': 'bugatti',
  // Российские и СНГ
  'лада': 'lada',
  'ваз': 'vaz',
  'газ': 'gaz',
  'уаз': 'uaz',
  'москвич': 'moskvich',
  'камаз': 'kamaz',
  // Таджикское написание (буквы ҳ, ҷ, ғ, қ, ӣ, ӯ)
  'ҳонда': 'honda',
  'ҳюндай': 'hyundai',
  'ҳендай': 'hyundai',
  'ҳундай': 'hyundai',
  'ҳавал': 'haval',
  'ҷили': 'geely',
  'ҷанган': 'changan',
  'ҷип': 'jeep',
  'ғаз': 'gaz',
  'мерседес-бенз': 'mercedes',
  // Частые опечатки и разговорные написания
  'бнв': 'bmw',
  'фолсваген': 'volkswagen',
  'чип': 'jeep',
  'ситройен': 'citroen',
  'ройс': 'rolls-royce',
  'ройс ройс': 'rolls-royce',
  'ролс ройс': 'rolls-royce',
  'ролс-ройс': 'rolls-royce',
};

/// Убирает символы, которые ломают фильтр PostgREST (запятые, скобки, звёздочки и т.п.).
String _clean(String s) => s.replaceAll(RegExp(r'[,()%*"\\]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Список строк для поиска по названию: исходный запрос и, если это известный бренд, его латиница.
List<String> searchVariants(String raw) {
  final q = _clean(raw);
  if (q.isEmpty) return const [];
  final out = <String>{q};
  final alias = _brandAliases[q.toLowerCase()];
  if (alias != null) out.add(alias);
  return out.toList();
}
