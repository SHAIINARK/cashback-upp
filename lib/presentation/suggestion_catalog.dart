/// Exact text suggestions only; these are never stored until the user chooses them.
const commonCategorySuggestions = <String>[
  'Все покупки',
  'Супермаркеты',
  'Аптеки',
  'Такси',
  'Транспорт',
  'АЗС',
  'Кафе и рестораны',
  'Фастфуд',
  'Маркетплейсы',
  'Одежда и обувь',
  'Дом и ремонт',
  'Красота и здоровье',
  'Связь и интернет',
  'Путешествия',
  'Развлечения',
  'ЖКХ',
];

List<String> categorySuggestions(Iterable<String> saved) => {
  ...commonCategorySuggestions,
  ...saved.where((value) => value.trim().isNotEmpty),
}.toList();
