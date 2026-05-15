const List<String> kConstructionStages = <String>[
  'Подготовка участка',
  'Фундамент',
  'Стены',
  'Кровля',
  'Инженерные сети',
  'Отделка',
  'Сдача объекта',
];

const Map<String, List<String>> kStageDescriptionItems = <String, List<String>>{
  'Подготовка участка': <String>[
    'Планировка',
    'Подъездные пути',
    'Временное электроснабжение'
  ],
  'Фундамент': <String>[
    'Разметка',
    'Земляные работы',
    'Армирование',
    'Бетонирование'
  ],
  'Стены': <String>['Возведение стен', 'Перемычки', 'Проемы'],
  'Кровля': <String>['Стропильная система', 'Гидроизоляция', 'Покрытие'],
  'Инженерные сети': <String>[
    'Электрика',
    'Водоснабжение',
    'Канализация',
    'Отопление'
  ],
  'Отделка': <String>[
    'Черновая отделка',
    'Чистовая отделка',
    'Установка оборудования'
  ],
  'Сдача объекта': <String>['Проверка', 'Акты', 'Передача ключей'],
};

const Map<String, String> kProjectStatusLabels = <String, String>{
  'draft': 'Черновик',
  'in_progress': 'В работе',
  'completed': 'Завершён',
  'on_hold': 'Приостановлен',
  'cancelled': 'Отменён',
};

const Map<String, String> kStageStatusLabels = <String, String>{
  'not_started': 'Запланировано',
  'in_progress': 'В работе',
  'completed': 'Выполнено',
  'overdue': 'Проблема',
};

const Map<String, String> kRoleLabels = <String, String>{
  'admin': 'Администратор',
  'director': 'Руководитель',
  'foreman': 'Прораб',
  'manager': 'Менеджер по продажам',
  'accountant': 'Бухгалтер',
  'client': 'Клиент',
};
