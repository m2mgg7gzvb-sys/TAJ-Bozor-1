/// Варианты написания для поиска: русское название бренда ищет и по латинице.
/// Например, «бмв» находит объявления, где написано «BMW».
const _brandAliases = <String, String>{
  'бмв': 'bmw',
  'бмвэ': 'bmw',
  'мерс': 'mercedes',
  'мерседес': 'mercedes',
  'мерседес-бенц': 'mercedes',
  'ауди': 'audi',
  'тойота': 'toyota',
  'лексус': 'lexus',
  'лада': 'lada',
  'ваз': 'vaz',
  'хонда': 'honda',
  'хонда сивик': 'honda civic',
  'ниссан': 'nissan',
  'нисан': 'nissan',
  'мерседас': 'mercedes',
  'тайота': 'toyota',
  'мазда': 'mazda',
  'киа': 'kia',
  'хендай': 'hyundai',
  'хюндай': 'hyundai',
  'шевроле': 'chevrolet',
  'шкода': 'skoda',
  'фольксваген': 'volkswagen',
  'фольц': 'volkswagen',
  'рено': 'renault',
  'пежо': 'peugeot',
  'ситроен': 'citroen',
  'опель': 'opel',
  'форд': 'ford',
  'вольво': 'volvo',
  'порше': 'porsche',
  'порш': 'porsche',
  'порщ': 'porsche',
  'порсче': 'porsche',
  'мицубиси': 'mitsubishi',
  'субару': 'subaru',
  'джип': 'jeep',
  'исузу': 'isuzu',
  'лэндровер': 'land rover',
  'ленд ровер': 'land rover',
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
