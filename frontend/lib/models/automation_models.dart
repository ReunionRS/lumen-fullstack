enum AutomationScenarioStatus {
  normal,
  warning,
  critical,
}

enum AutomationOperator {
  equals,
  notEquals,
  greater,
  less,
  detected,
  notDetected,
}

enum AutomationConditionType {
  always,
  timeRange,
  userAtHome,
  userAway,
  nightOnly,
  dayOnly,
}

enum AutomationActionType {
  pushNotification,
  turnOnDevice,
  turnOffDevice,
  shutOffWater,
  turnOnSiren,
  addJournalEvent,
  createMaintenanceReminder,
  createWarning,
  setTemperature,
  turnOnVentilation,
}

class AutomationTrigger {
  const AutomationTrigger({
    required this.sensorName,
    required this.operatorType,
    required this.value,
  });

  final String sensorName;
  final AutomationOperator operatorType;
  final String value;
}

class AutomationCondition {
  const AutomationCondition({
    required this.type,
    this.startTime = '',
    this.endTime = '',
  });

  final AutomationConditionType type;
  final String startTime;
  final String endTime;
}

class AutomationAction {
  const AutomationAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
  });

  final String id;
  final AutomationActionType type;
  final String title;
  final String description;
}

class AutomationScenario {
  const AutomationScenario({
    required this.id,
    required this.systemType,
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.trigger,
    required this.condition,
    required this.actions,
    required this.lastTriggeredAt,
    required this.status,
  });

  final String id;
  final String systemType;
  final String title;
  final String description;
  final bool isEnabled;
  final AutomationTrigger trigger;
  final AutomationCondition condition;
  final List<AutomationAction> actions;
  final String lastTriggeredAt;
  final AutomationScenarioStatus status;

  AutomationScenario copyWith({
    String? id,
    String? systemType,
    String? title,
    String? description,
    bool? isEnabled,
    AutomationTrigger? trigger,
    AutomationCondition? condition,
    List<AutomationAction>? actions,
    String? lastTriggeredAt,
    AutomationScenarioStatus? status,
  }) {
    return AutomationScenario(
      id: id ?? this.id,
      systemType: systemType ?? this.systemType,
      title: title ?? this.title,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      trigger: trigger ?? this.trigger,
      condition: condition ?? this.condition,
      actions: actions ?? this.actions,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      status: status ?? this.status,
    );
  }
}
