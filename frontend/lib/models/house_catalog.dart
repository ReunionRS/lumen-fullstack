class HouseCatalogItem {
  const HouseCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    required this.url,
    required this.areaSqm,
    required this.livingAreaSqm,
    required this.floors,
    required this.materials,
    required this.priceRub,
    required this.layout,
  });

  final String id;
  final String name;
  final String category;
  final String url;
  final num areaSqm;
  final num livingAreaSqm;
  final int floors;
  final String materials;
  final num priceRub;
  final String layout;

  String get label => '$name · ${areaSqm.toStringAsFixed(0)} м²';
}

const houseCatalogItems = <HouseCatalogItem>[
  HouseCatalogItem(
    id: 'smart-2-177',
    name: 'Загородный дом «СМАРТ 2-177»',
    category: 'Готовый дом',
    url: 'https://cklumen.ru/dom/zagorodnyj-dom-smart-2-177/',
    areaSqm: 210,
    livingAreaSqm: 177,
    floors: 2,
    materials: 'Газобетон',
    priceRub: 10800000,
    layout: '3 санузла, кухня-гостиная, 3 спальни, котельная',
  ),
  HouseCatalogItem(
    id: 'smart-1-87',
    name: 'Загородный дом «СМАРТ 1-87»',
    category: 'Готовый дом',
    url: 'https://cklumen.ru/dom/zagorodnyj-dom-smart-1-87/',
    areaSqm: 100,
    livingAreaSqm: 87,
    floors: 1,
    materials: 'Газобетон',
    priceRub: 4800000,
    layout: '2 санузла, кухня-гостиная, 2 спальни, котельная',
  ),
  HouseCatalogItem(
    id: 'smart-1-90',
    name: 'Типовой загородный дом «СМАРТ 1-90»',
    category: 'Типовой проект',
    url: 'https://cklumen.ru/dom/tipovoj-zagorodnyj-dom-smart-1-90/',
    areaSqm: 110,
    livingAreaSqm: 90,
    floors: 1,
    materials: 'Газобетон',
    priceRub: 5100000,
    layout:
        '3 спальни, 2 санузла и ванна, терраса, гостиная с кухней и столовой, хозяйственное помещение',
  ),
  HouseCatalogItem(
    id: 'smart-1-175',
    name: 'Типовой загородный дом «СМАРТ 1-175»',
    category: 'Типовой проект',
    url: 'https://cklumen.ru/dom/tipovoj-proekt-smart-1-175/',
    areaSqm: 191,
    livingAreaSqm: 175,
    floors: 2,
    materials: 'Газобетон',
    priceRub: 10400000,
    layout:
        '2 санузла, котельная, 4 спальни, холл, кухня-гостиная, гардеробная, терраса',
  ),
  HouseCatalogItem(
    id: 'smart-2-99',
    name: 'Типовой загородный дом «СМАРТ 2-99»',
    category: 'Типовой проект',
    url: 'https://cklumen.ru/dom/tipovoj-proekt-smart-2-99/',
    areaSqm: 144,
    livingAreaSqm: 99,
    floors: 2,
    materials: 'Газобетон',
    priceRub: 5900000,
    layout:
        '2 санузла, котельная, 4 спальни, 2 холла, кухня-гостиная, гардеробная, терраса',
  ),
  HouseCatalogItem(
    id: 'smart-1-145',
    name: 'Типовой загородный дом «СМАРТ 1-145»',
    category: 'Типовой проект',
    url: 'https://cklumen.ru/dom/tipovoj-proekt-smart-1-145/',
    areaSqm: 154,
    livingAreaSqm: 145,
    floors: 1,
    materials: 'Газобетон',
    priceRub: 7390000,
    layout:
        '2 санузла, котельная, 3 спальни, холл, кухня-гостиная, гардеробная, терраса',
  ),
  HouseCatalogItem(
    id: 'smart-1-100',
    name: 'Типовой загородный дом «СМАРТ 1-100»',
    category: 'Типовой проект',
    url: 'https://cklumen.ru/dom/tipovoj-proekt-smart-1-100/',
    areaSqm: 130,
    livingAreaSqm: 100,
    floors: 1,
    materials: 'Газобетон',
    priceRub: 6240000,
    layout: '2 санузла, котельная, 3 спальни, холл, кухня-гостиная',
  ),
];
