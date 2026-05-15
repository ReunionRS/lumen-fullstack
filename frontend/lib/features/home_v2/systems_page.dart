import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/automation_models.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/system_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';

String _mapSystemCategory(SystemEntity item) {
  final id = item.entityId.toLowerCase();
  final name = item.friendlyName.toLowerCase();
  final dc = item.deviceClass.toLowerCase();
  final domain = item.domain.toLowerCase();

  if (dc == 'energy' ||
      dc == 'power' ||
      dc == 'current' ||
      dc == 'voltage' ||
      id.contains('energy') ||
      id.contains('electric') ||
      id.contains('power') ||
      id.contains('voltage') ||
      id.contains('current') ||
      name.contains('элект') ||
      name.contains('энер') ||
      name.contains('счетчик')) {
    return 'electric';
  }
  if (dc == 'moisture' ||
      id.contains('water') ||
      id.contains('leak') ||
      name.contains('вода')) {
    return 'water';
  }
  if (dc == 'temperature' ||
      id.contains('boiler') ||
      id.contains('heat') ||
      id.contains('otopl') ||
      name.contains('котел') ||
      name.contains('отоп') ||
      name.contains('темпер')) {
    return 'heating';
  }
  if (domain == 'camera' || id.contains('camera') || name.contains('камер')) {
    return 'camera';
  }
  if (dc == 'smoke' ||
      dc == 'gas' ||
      dc == 'carbon_monoxide' ||
      dc == 'carbon_dioxide' ||
      dc == 'safety' ||
      dc == 'problem' ||
      id.contains('smoke') ||
      id.contains('gas') ||
      id.contains('co2') ||
      id.contains('alarm') ||
      id.contains('security') ||
      name.contains('дым') ||
      name.contains('газ') ||
      name.contains('сигнал')) {
    return 'safety';
  }
  if (domain == 'fan' ||
      id.contains('vent') ||
      name.contains('вент') ||
      name.contains('вытяж')) {
    return 'ventilation';
  }
  if (domain == 'light' || domain == 'switch') return 'electric';
  if (dc == 'humidity' || id.contains('humid') || name.contains('влаж')) {
    return 'water';
  }
  if (domain == 'climate') return 'heating';
  return 'other';
}

class SystemsPage extends StatefulWidget {
  const SystemsPage({
    super.key,
    required this.auth,
    required this.role,
    this.projectId,
  });

  final AuthService auth;
  final String role;
  final String? projectId;

  @override
  State<SystemsPage> createState() => _SystemsPageState();
}

class _SystemsPageState extends State<SystemsPage> {
  final List<SystemEntity> _items = [];
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];
  Timer? _realtimeTimer;

  String? _selectedClientId;
  String? _selectedProjectId;
  bool _loading = true;
  bool _syncing = false;
  String? _error;

  bool get _isClient => widget.role == 'client';
  String? get _activeProjectId =>
      _isClient ? widget.projectId : _selectedProjectId;
  bool get _needsSelection =>
      !_isClient && (_selectedClientId == null || _selectedProjectId == null);

  @override
  void initState() {
    super.initState();
    if (_isClient) {
      _selectedProjectId = widget.projectId;
      _loadStatus();
    } else {
      _loadSelectors();
    }
    _startRealtime();
  }

  @override
  void dispose() {
    _realtimeTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SystemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isClient &&
        oldWidget.projectId != widget.projectId &&
        widget.projectId != null &&
        widget.projectId!.isNotEmpty) {
      _selectedProjectId = widget.projectId;
      _loadStatus();
    }
  }

  void _startRealtime() {
    _realtimeTimer?.cancel();
    _realtimeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final projectId = _activeProjectId;
      if (projectId == null || projectId.isEmpty) return;
      _loadStatus(silent: true);
    });
  }

  Future<void> _loadSelectors() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.auth.fetchUsers();
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() {
        _clients
          ..clear()
          ..addAll(users
              .where((u) => u.role == 'client' && u.isActive && !u.isArchived));
        _projects
          ..clear()
          ..addAll(projects);
        _loading = false;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = I18n.t('Сессия истекла. Войдите снова.',
            'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.',
            tt: 'Сессия тәмамланды. Кабат керегез.',
            ba: 'Сессия тамамланды. Ҡабат инегеҙ.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadStatus({bool silent = false}) async {
    final projectId = _activeProjectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _loading = false;
        _syncing = false;
        _items.clear();
      });
      return;
    }

    setState(() {
      if (silent) {
        _syncing = true;
      } else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final items = await widget.auth.fetchSystemStatus(projectId: projectId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
        _loading = false;
        _syncing = false;
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _error = I18n.t('Сессия истекла. Войдите снова.',
            'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.',
            tt: 'Сессия тәмамланды. Кабат керегез.',
            ba: 'Сессия тамамланды. Ҡабат инегеҙ.');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<ProjectSummary> get _clientProjects {
    if (_selectedClientId == null) return const [];
    return _projects
        .where((p) => p.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(
        title: Text(I18n.t(
          'Системы',
          'Системаос',
          'Systems',
          tt: 'Системалар',
          ba: 'Системалар',
        )),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _EmptyState(
        title: I18n.t('Ошибка', 'Йӧслык', 'Error', tt: 'Хата', ba: 'Хата'),
        subtitle: _error!,
      );
    }
    if (_needsSelection) {
      return _buildSelectionView();
    }
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: I18n.t(
            'Объект не выбран', 'Объект уг бырйы', 'Project not selected',
            tt: 'Объект сайланмаган', ba: 'Объект һайланмаған'),
        subtitle: I18n.t('Выберите объект, чтобы видеть системы',
            'Системаосез адӟыны объект бырйы', 'Select project to view systems',
            tt: 'Системаларны күрү өчен объект сайлагыз',
            ba: 'Системаларҙы күреү өсөн объект һайлағыҙ'),
      );
    }

    final grouped = _groupedByCategory();
    final categories = grouped.keys.toList(growable: false)
      ..sort((a, b) {
        if (a == 'other' && b != 'other') return 1;
        if (b == 'other' && a != 'other') return -1;
        return _categoryTitle(a).compareTo(_categoryTitle(b));
      });

    return RefreshIndicator(
      onRefresh: _loadStatus,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
        children: [
          if (_syncing)
            LinearProgressIndicator(
              minHeight: 2,
              color: UiTokens.accent,
              backgroundColor: UiTokens.surface(context),
            ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            _EmptyState(
              title: I18n.t('Нет данных', 'Даннайос ӧвӧл', 'No data',
                  tt: 'Мәгълүмат юк', ba: 'Мәғлүмәт юҡ'),
              subtitle: I18n.t(
                  'Данные из Home Assistant пока не получены',
                  'Home Assistant-ысь даннайос али уг басьтӥсько',
                  'No data received from Home Assistant yet',
                  tt: 'Home Assistant мәгълүматы әлегә алынмады',
                  ba: 'Home Assistant мәғлүмәте әлегә алынманы'),
            )
          else
            ...categories.map(
              (category) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCategoryTile(
                  category: category,
                  items: grouped[category] ?? const <SystemEntity>[],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<SystemEntity>> _groupedByCategory() {
    final map = <String, List<SystemEntity>>{};
    for (final item in _items.where(_isRelevantEntity)) {
      final cat = _categoryKey(item);
      map.putIfAbsent(cat, () => <SystemEntity>[]);
      map[cat]!.add(item);
    }
    return map;
  }

  bool _isRelevantEntity(SystemEntity item) {
    final domain = item.domain.toLowerCase();
    final id = item.entityId.toLowerCase();
    final name = item.friendlyName.toLowerCase();
    final dc = item.deviceClass.toLowerCase();
    final entityCategory =
        (item.attributes['entity_category'] ?? '').toString().toLowerCase();

    const allowedDomains = {
      'sensor',
      'binary_sensor',
      'switch',
      'light',
      'camera',
      'climate',
      'fan',
      'input_number',
      'input_boolean',
    };
    if (!allowedDomains.contains(domain)) return false;
    if (entityCategory == 'diagnostic' || entityCategory == 'config') {
      return false;
    }

    if (id == 'sun.sun' ||
        id.startsWith('update.') ||
        id.startsWith('event.') ||
        id.startsWith('automation.') ||
        id.startsWith('scene.') ||
        id.startsWith('script.') ||
        id.startsWith('device_tracker.') ||
        id.startsWith('conversation.') ||
        id.contains('backup') ||
        id.contains('last_attempted_automatic_backup') ||
        name.contains('backup') ||
        name.contains('резервн') ||
        id.contains('home_assistant') ||
        id.contains('updater')) {
      return false;
    }

    final isTarget = dc == 'temperature' ||
        dc == 'humidity' ||
        dc == 'smoke' ||
        dc == 'moisture' ||
        dc == 'energy' ||
        dc == 'power' ||
        dc == 'current' ||
        dc == 'voltage' ||
        dc == 'gas' ||
        dc == 'carbon_monoxide' ||
        dc == 'carbon_dioxide' ||
        dc == 'safety' ||
        domain == 'camera' ||
        domain == 'climate' ||
        domain == 'fan' ||
        domain == 'light' ||
        domain == 'switch' ||
        id.contains('boiler') ||
        id.contains('smoke') ||
        id.contains('leak') ||
        id.contains('water') ||
        id.contains('energy') ||
        id.contains('power') ||
        id.contains('electric') ||
        id.contains('humid') ||
        id.contains('temp') ||
        id.contains('camera') ||
        id.contains('vent') ||
        name.contains('котел') ||
        name.contains('элект') ||
        name.contains('счетчик') ||
        name.contains('энер') ||
        name.contains('дым') ||
        name.contains('протеч') ||
        name.contains('камера') ||
        name.contains('влаж') ||
        name.contains('темпер');

    return isTarget || allowedDomains.contains(domain);
  }

  String _categoryKey(SystemEntity item) {
    return _mapSystemCategory(item);
  }

  String _categoryTitle(String key) {
    switch (key) {
      case 'electric':
        return I18n.t('Электроснабжение', 'Электрика', 'Electricity',
            tt: 'Электрика', ba: 'Электрика');
      case 'water':
        return I18n.t('Водоснабжение', 'Вумос туськон', 'Water supply',
            tt: 'Су белән тәэмин итү', ba: 'Һыу менән тәьмин итеү');
      case 'heating':
        return I18n.t('Отопление', 'Шундытон', 'Heating',
            tt: 'Җылыту', ba: 'Йылытыу');
      case 'ventilation':
        return I18n.t('Вентиляция', 'Вентиляция', 'Ventilation',
            tt: 'Вентиляция', ba: 'Елләү');
      case 'camera':
        return I18n.t('Камеры', 'Камераос', 'Cameras',
            tt: 'Камералар', ba: 'Камералар');
      case 'safety':
        return I18n.t('Безопасность', 'Утинлык', 'Safety',
            tt: 'Иминлек', ba: 'Хәүефһеҙлек');
      default:
        return I18n.t('Другое', 'Мукет', 'Other', tt: 'Башка', ba: 'Башҡа');
    }
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'electric':
        return Icons.bolt_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'heating':
        return Icons.local_fire_department_outlined;
      case 'ventilation':
        return Icons.air_outlined;
      case 'camera':
        return Icons.videocam_outlined;
      case 'safety':
        return Icons.shield_outlined;
      default:
        return Icons.settings_outlined;
    }
  }

  Widget _buildCategoryTile({
    required String category,
    required List<SystemEntity> items,
  }) {
    final hasAlarm = items.any((item) {
      final state = item.state.toLowerCase();
      final dc = item.deviceClass.toLowerCase();
      return (dc == 'smoke' || dc == 'moisture') &&
          (state == 'on' || state == 'detected' || state == 'true');
    });

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _CategoryDetailsPage(
              auth: widget.auth,
              projectId: _activeProjectId!,
              role: widget.role,
              title: _categoryTitle(category),
              categoryKey: category,
              icon: _categoryIcon(category),
              initialItems: items,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: UiTokens.cardShadow(context),
          border: Border.all(color: UiTokens.border(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: UiTokens.surface(context),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_categoryIcon(category), color: UiTokens.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _categoryTitle(category),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _categoryMetric(items),
                    style: TextStyle(
                      fontSize: 12,
                      color: UiTokens.muted(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${I18n.t('Статус', 'Статус', 'Status')}: ${hasAlarm ? I18n.t('Внимание', 'Игьтисал', 'Attention', tt: 'Игътибар', ba: 'Иғтибар') : I18n.t('Норма', 'Норма', 'Normal', tt: 'Норма', ba: 'Норма')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasAlarm ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: UiTokens.muted(context)),
          ],
        ),
      ),
    );
  }

  String _categoryMetric(List<SystemEntity> items) {
    if (items.isEmpty) return I18n.t('Нет данных', 'Даннайос ӧвӧл', 'No data');

    final temp = items
        .where((e) => e.deviceClass.toLowerCase() == 'temperature')
        .toList(growable: false);
    if (temp.isNotEmpty) {
      final first = temp.first;
      return '${I18n.t('Температура', 'Температура', 'Temperature')}: ${first.state}${first.unit.isNotEmpty ? ' ${first.unit}' : ''}';
    }

    final energy = items
        .where((e) =>
            e.deviceClass.toLowerCase() == 'energy' ||
            e.deviceClass.toLowerCase() == 'power')
        .toList(growable: false);
    if (energy.isNotEmpty) {
      final first = energy.first;
      return '${I18n.t('Потребление', 'Потребление', 'Consumption')}: ${first.state}${first.unit.isNotEmpty ? ' ${first.unit}' : ''}';
    }

    return '${I18n.t('Устройств', 'Устройствоос', 'Devices')}: ${items.length}';
  }

  Widget _buildSelectionView() {
    if (_clients.isEmpty) {
      return _EmptyState(
        title: I18n.t('Нет клиентов', 'Клиентъёс ӧвӧл', 'No clients',
            tt: 'Клиентлар юк', ba: 'Клиенттар юҡ'),
        subtitle: I18n.t('Сначала добавьте клиента в системе',
            'Клиентез системае суты', 'Add a client first',
            tt: 'Башта системага клиент өстәгез',
            ba: 'Башта системаға клиент өҫтәгеҙ'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          I18n.t('Сначала выберите клиента', 'Клиентез башта бырйы',
              'Select a client first',
              tt: 'Башта клиентны сайлагыз', ba: 'Башта клиентты һайлағыҙ'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          I18n.t(
              'После выбора клиента и объекта данные будут загружены',
              'Клиент но объект бырйыса бере, даннайос грузитчозы',
              'Data loads after selecting client and project',
              tt: 'Клиент һәм объект сайлангач мәгълүмат йөкләнә',
              ba: 'Клиент һәм объект һайланғас мәғлүмәт йөкләнә'),
          style: TextStyle(color: UiTokens.muted(context)),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: UiTokens.card(context),
            borderRadius: BorderRadius.circular(18),
            boxShadow: UiTokens.cardShadow(context),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedClientId,
                items: _clients
                    .map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.fio),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClientId = value;
                    _selectedProjectId = null;
                    _items.clear();
                  });
                },
                decoration: InputDecoration(
                  labelText: I18n.t('Клиент', 'Клиент', 'Client',
                      tt: 'Клиент', ba: 'Клиент'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                items: _clientProjects
                    .map((p) => DropdownMenuItem<String>(
                          value: p.id,
                          child: Text(p.constructionAddress),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedProjectId = value);
                  _loadStatus();
                },
                decoration: InputDecoration(
                  labelText: I18n.t('Объект', 'Объект', 'Project',
                      tt: 'Объект', ba: 'Объект'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryDetailsPage extends StatefulWidget {
  const _CategoryDetailsPage({
    required this.auth,
    required this.projectId,
    required this.role,
    required this.title,
    required this.categoryKey,
    required this.icon,
    required this.initialItems,
  });

  final AuthService auth;
  final String projectId;
  final String role;
  final String title;
  final String categoryKey;
  final IconData icon;
  final List<SystemEntity> initialItems;

  @override
  State<_CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<_CategoryDetailsPage> {
  final List<SystemEntity> _items = [];
  late final AutomationRepository _automationRepository;
  List<AutomationScenario> _scenarios = const [];
  int _tab = 0;
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _automationRepository = InMemoryAutomationRepository.initial();
    _items
      ..clear()
      ..addAll(widget.initialItems);
    _loading = false;
    _scenarios = _automationRepository.getScenarios(widget.categoryKey);
    _load(silent: true);
    _timer =
        Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (silent) {
        _syncing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });
    try {
      final all =
          await widget.auth.fetchSystemStatus(projectId: widget.projectId);
      if (!mounted) return;
      final filtered = all
          .where((e) => _keyFor(e) == widget.categoryKey)
          .toList(growable: false);
      setState(() {
        _items
          ..clear()
          ..addAll(filtered);
        _loading = false;
        _syncing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _syncing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _keyFor(SystemEntity item) {
    return _mapSystemCategory(item);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF0A0A0A), Color(0xFF121212)]
                    : const [Color(0xFFFF7A00), Color(0xFFE55A00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 12),
                Text(widget.title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '${I18n.t('Статус', 'Статус', 'Status')}: ${_hasAlarm() ? I18n.t('Внимание', 'Игьтисал', 'Attention', tt: 'Игътибар', ba: 'Иғтибар') : I18n.t('Норма', 'Норма', 'Normal', tt: 'Норма', ba: 'Норма')}',
                  style: TextStyle(
                    color: _hasAlarm()
                        ? Colors.yellow.shade100
                        : Colors.green.shade100,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: UiTokens.card(context),
            child: Row(
              children: [
                _TabBtn(
                    label: I18n.t('Датчики', 'Датчикъёс', 'Sensors'),
                    active: _tab == 0,
                    onTap: () => setState(() => _tab = 0)),
                _TabBtn(
                    label: I18n.t('Устройства', 'Устройствоос', 'Devices'),
                    active: _tab == 1,
                    onTap: () => setState(() => _tab = 1)),
                _TabBtn(
                    label: I18n.t('Автоматика', 'Автоматика', 'Automation'),
                    active: _tab == 2,
                    onTap: () => setState(() => _tab = 2)),
              ],
            ),
          ),
          if (_syncing)
            LinearProgressIndicator(
                minHeight: 2,
                color: UiTokens.accent,
                backgroundColor: UiTokens.surface(context)),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent)))
                    : _tab == 2
                        ? _buildAutomationTab()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 22),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: UiTokens.card(context),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: UiTokens.border(context)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(_statusIcon(item),
                                          color: _statusColor(item)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.friendlyName.isEmpty
                                                  ? item.entityId
                                                  : item.friendlyName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color: UiTokens.foreground(
                                                      context),
                                                  fontWeight: FontWeight.w600),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.entityId,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  color:
                                                      UiTokens.muted(context),
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        item.unit.isEmpty
                                            ? item.state
                                            : '${item.state} ${item.unit}',
                                        style: TextStyle(
                                          color: _statusColor(item),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutomationTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (_scenarios.isEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: UiTokens.border(context)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: UiTokens.accent,
                  size: 30,
                ),
                const SizedBox(height: 10),
                Text(
                  'Еще нет сценариев автоматизации,\nнажмите на + чтобы добавить их',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: UiTokens.muted(context),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openScenarioBuilder,
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить сценарий'),
                  ),
                ),
              ],
            ),
          )
        else
          ..._scenarios.map(
            (scenario) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AutomationScenarioCard(
                scenario: scenario,
                onTap: () => _openScenarioDetails(scenario),
                onSwitch: (value) => _toggleScenario(scenario.id, value),
              ),
            ),
          ),
      ],
    );
  }

  void _toggleScenario(String id, bool value) {
    _automationRepository.toggleScenario(widget.categoryKey, id, value);
    setState(() {
      _scenarios = _automationRepository.getScenarios(widget.categoryKey);
    });
  }

  void _openScenarioDetails(AutomationScenario scenario) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: UiTokens.card(context),
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final current = _scenarios.firstWhere(
          (s) => s.id == scenario.id,
          orElse: () => scenario,
        );
        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 18,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                current.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: UiTokens.foreground(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                current.description,
                style: TextStyle(color: UiTokens.muted(ctx), height: 1.35),
              ),
              const SizedBox(height: 14),
              _RuleBlock(
                title: 'ЕСЛИ',
                text:
                    '${current.trigger.sensorName} ${_operatorLabel(current.trigger.operatorType)} ${current.trigger.value}',
              ),
              const SizedBox(height: 8),
              _RuleBlock(
                title: 'И',
                text: _conditionLabel(current.condition),
              ),
              const SizedBox(height: 8),
              _RuleBlock(
                title: 'ТО',
                text: current.actions
                    .map((a) =>
                        '• ${a.title}${a.description.isEmpty ? '' : ' — ${a.description}'}')
                    .join('\n'),
              ),
              const SizedBox(height: 14),
              Text(
                'Последнее срабатывание: ${current.lastTriggeredAt}',
                style: TextStyle(color: UiTokens.muted(ctx)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  _toggleScenario(current.id, !current.isEnabled);
                  Navigator.of(ctx).pop();
                },
                icon: Icon(
                    current.isEnabled ? Icons.toggle_off : Icons.toggle_on),
                label: Text(current.isEnabled ? 'Выключить' : 'Включить'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                onPressed: () async {
                  final shouldDelete =
                      await _confirmDeleteScenario(ctx, current);
                  if (shouldDelete != true) return;
                  _automationRepository.deleteScenario(
                      widget.categoryKey, current.id);
                  if (!mounted) return;
                  setState(() {
                    _scenarios =
                        _automationRepository.getScenarios(widget.categoryKey);
                  });
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сценарий удалён')),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _confirmDeleteScenario(
      BuildContext ctx, AutomationScenario scenario) {
    return showDialog<bool>(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Удалить сценарий?'),
        content: const Text(
          'Сценарий будет удалён из автоматики этой системы. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Future<void> _openScenarioBuilder() async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final triggerValueController = TextEditingController();
    final timeStartController = TextEditingController();
    final timeEndController = TextEditingController();

    String? triggerSensor;
    AutomationOperator? triggerOperator;
    AutomationConditionType conditionType = AutomationConditionType.always;
    AutomationActionType nextActionType = AutomationActionType.pushNotification;
    final actions = <AutomationAction>[];

    final sensors = const [
      'Датчик протечки',
      'Температура в помещении',
      'Давление воды',
      'Датчик движения',
      'Датчик открытия двери',
      'CO₂',
      'Влажность',
      'Дата обслуживания',
    ];

    final result = await showModalBottomSheet<AutomationScenario>(
      context: context,
      isScrollControlled: true,
      backgroundColor: UiTokens.card(context),
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final isTimeRange =
                conditionType == AutomationConditionType.timeRange;
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'Новый сценарий',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: UiTokens.foreground(ctx),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: titleController,
                      decoration:
                          const InputDecoration(labelText: 'Название сценария'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Укажите название сценария'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: descriptionController,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Описание сценария'),
                    ),
                    const SizedBox(height: 12),
                    Text('ЕСЛИ',
                        style: TextStyle(
                            color: UiTokens.accent,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: triggerSensor,
                      items: sensors
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(growable: false),
                      onChanged: (v) => setModal(() => triggerSensor = v),
                      decoration:
                          const InputDecoration(labelText: 'Датчик / событие'),
                      validator: (_) =>
                          triggerSensor == null ? 'Выберите триггер' : null,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AutomationOperator>(
                      value: triggerOperator,
                      items: AutomationOperator.values
                          .map((o) => DropdownMenuItem(
                                value: o,
                                child: Text(_operatorLabel(o)),
                              ))
                          .toList(growable: false),
                      onChanged: (v) => setModal(() => triggerOperator = v),
                      decoration: const InputDecoration(labelText: 'Оператор'),
                      validator: (_) =>
                          triggerOperator == null ? 'Выберите оператор' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: triggerValueController,
                      decoration: const InputDecoration(labelText: 'Значение'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Укажите значение'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text('И',
                        style: TextStyle(
                            color: UiTokens.accent,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<AutomationConditionType>(
                      value: conditionType,
                      items: AutomationConditionType.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(_conditionTypeLabel(c)),
                              ))
                          .toList(growable: false),
                      onChanged: (v) {
                        if (v == null) return;
                        setModal(() => conditionType = v);
                      },
                      decoration: const InputDecoration(labelText: 'Условие'),
                    ),
                    if (isTimeRange) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: timeStartController,
                              decoration: const InputDecoration(
                                  labelText: 'Время начала'),
                              validator: (_) {
                                if (!isTimeRange) return null;
                                if (timeStartController.text.trim().isEmpty) {
                                  return 'Укажите начало';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: timeEndController,
                              decoration: const InputDecoration(
                                  labelText: 'Время окончания'),
                              validator: (_) {
                                if (!isTimeRange) return null;
                                if (timeEndController.text.trim().isEmpty) {
                                  return 'Укажите окончание';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('ТО',
                        style: TextStyle(
                            color: UiTokens.accent,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<AutomationActionType>(
                            value: nextActionType,
                            items: AutomationActionType.values
                                .map((a) => DropdownMenuItem(
                                      value: a,
                                      child: Text(_actionTypeLabel(a)),
                                    ))
                                .toList(growable: false),
                            onChanged: (v) {
                              if (v == null) return;
                              setModal(() => nextActionType = v);
                            },
                            decoration: const InputDecoration(
                                labelText: 'Тип действия'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            final id = DateTime.now()
                                .microsecondsSinceEpoch
                                .toString();
                            final title = _actionTypeLabel(nextActionType);
                            setModal(() {
                              actions.add(
                                AutomationAction(
                                  id: id,
                                  type: nextActionType,
                                  title: title,
                                  description: 'Добавлено пользователем',
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (actions.isEmpty)
                      Text(
                        'Добавьте хотя бы одно действие',
                        style:
                            TextStyle(color: UiTokens.muted(ctx), fontSize: 12),
                      )
                    else
                      ...actions.map(
                        (a) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(a.title),
                          subtitle: Text(a.description),
                          trailing: IconButton(
                            onPressed: () {
                              setModal(() {
                                actions.removeWhere((x) => x.id == a.id);
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () {
                        final valid = formKey.currentState?.validate() ?? false;
                        if (!valid) return;
                        if (actions.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Добавьте хотя бы одно действие')),
                          );
                          return;
                        }
                        final scenario = AutomationScenario(
                          id: DateTime.now().microsecondsSinceEpoch.toString(),
                          systemType: widget.categoryKey,
                          title: titleController.text.trim(),
                          description: descriptionController.text.trim(),
                          isEnabled: true,
                          trigger: AutomationTrigger(
                            sensorName: triggerSensor ?? '',
                            operatorType:
                                triggerOperator ?? AutomationOperator.equals,
                            value: triggerValueController.text.trim(),
                          ),
                          condition: AutomationCondition(
                            type: conditionType,
                            startTime: timeStartController.text.trim(),
                            endTime: timeEndController.text.trim(),
                          ),
                          actions: List<AutomationAction>.from(actions),
                          lastTriggeredAt: 'Не срабатывал',
                          status: AutomationScenarioStatus.normal,
                        );
                        Navigator.of(ctx).pop(scenario);
                      },
                      child: const Text('Сохранить сценарий'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    _automationRepository.createScenario(widget.categoryKey, result);
    if (!mounted) return;
    setState(() {
      _scenarios = _automationRepository.getScenarios(widget.categoryKey);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сценарий добавлен')),
    );
  }

  String _operatorLabel(AutomationOperator value) {
    switch (value) {
      case AutomationOperator.equals:
        return 'равно';
      case AutomationOperator.notEquals:
        return 'не равно';
      case AutomationOperator.greater:
        return 'больше';
      case AutomationOperator.less:
        return 'меньше';
      case AutomationOperator.detected:
        return 'обнаружено';
      case AutomationOperator.notDetected:
        return 'не обнаружено';
    }
  }

  String _conditionTypeLabel(AutomationConditionType value) {
    switch (value) {
      case AutomationConditionType.always:
        return 'выполнять всегда';
      case AutomationConditionType.timeRange:
        return 'только в определённое время';
      case AutomationConditionType.userAtHome:
        return 'только если пользователь дома';
      case AutomationConditionType.userAway:
        return 'только если пользователь вне дома';
      case AutomationConditionType.nightOnly:
        return 'только ночью';
      case AutomationConditionType.dayOnly:
        return 'только днём';
    }
  }

  String _conditionLabel(AutomationCondition condition) {
    final base = _conditionTypeLabel(condition.type);
    if (condition.type != AutomationConditionType.timeRange) return base;
    return '$base (${condition.startTime} — ${condition.endTime})';
  }

  String _actionTypeLabel(AutomationActionType value) {
    switch (value) {
      case AutomationActionType.pushNotification:
        return 'отправить push-уведомление';
      case AutomationActionType.turnOnDevice:
        return 'включить устройство';
      case AutomationActionType.turnOffDevice:
        return 'выключить устройство';
      case AutomationActionType.shutOffWater:
        return 'перекрыть воду';
      case AutomationActionType.turnOnSiren:
        return 'включить сирену';
      case AutomationActionType.addJournalEvent:
        return 'создать событие в журнале';
      case AutomationActionType.createMaintenanceReminder:
        return 'создать напоминание об обслуживании';
      case AutomationActionType.createWarning:
        return 'создать предупреждение';
      case AutomationActionType.setTemperature:
        return 'изменить температуру';
      case AutomationActionType.turnOnVentilation:
        return 'включить вентиляцию';
    }
  }

  bool _hasAlarm() {
    return _items.any((item) {
      final state = item.state.toLowerCase();
      final dc = item.deviceClass.toLowerCase();
      return (dc == 'smoke' || dc == 'moisture') &&
          (state == 'on' || state == 'detected' || state == 'true');
    });
  }

  IconData _statusIcon(SystemEntity item) {
    final state = item.state.toLowerCase();
    final dc = item.deviceClass.toLowerCase();
    if ((dc == 'smoke' || dc == 'moisture') &&
        (state == 'on' || state == 'detected' || state == 'true')) {
      return Icons.warning_amber_rounded;
    }
    return Icons.check_circle_outline_rounded;
  }

  Color _statusColor(SystemEntity item) {
    final state = item.state.toLowerCase();
    final dc = item.deviceClass.toLowerCase();
    if ((dc == 'smoke' || dc == 'moisture') &&
        (state == 'on' || state == 'detected' || state == 'true')) {
      return Colors.orange;
    }
    return Colors.green;
  }
}

class _AutomationScenarioCard extends StatelessWidget {
  const _AutomationScenarioCard({
    required this.scenario,
    required this.onTap,
    required this.onSwitch,
  });

  final AutomationScenario scenario;
  final VoidCallback onTap;
  final ValueChanged<bool> onSwitch;

  @override
  Widget build(BuildContext context) {
    final accent = switch (scenario.status) {
      AutomationScenarioStatus.normal => Colors.green,
      AutomationScenarioStatus.warning => Colors.orange,
      AutomationScenarioStatus.critical => Colors.redAccent,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: UiTokens.border(context)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    scenario.title,
                    style: TextStyle(
                      color: UiTokens.foreground(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: scenario.isEnabled,
                  onChanged: onSwitch,
                  activeColor: UiTokens.accent,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    scenario.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: UiTokens.muted(context), fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  scenario.isEnabled ? 'Включено' : 'Выключено',
                  style: TextStyle(
                    color: scenario.isEnabled
                        ? Colors.green
                        : UiTokens.muted(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Действий: ${scenario.actions.length}',
                  style:
                      TextStyle(color: UiTokens.muted(context), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleBlock extends StatelessWidget {
  const _RuleBlock({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: UiTokens.surface(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: UiTokens.accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(color: UiTokens.foreground(context))),
        ],
      ),
    );
  }
}

abstract class AutomationRepository {
  List<AutomationScenario> getScenarios(String systemType);
  void createScenario(String systemType, AutomationScenario scenario);
  void deleteScenario(String systemType, String scenarioId);
  void toggleScenario(String systemType, String scenarioId, bool isEnabled);
}

class InMemoryAutomationRepository implements AutomationRepository {
  InMemoryAutomationRepository(this._store);

  factory InMemoryAutomationRepository.initial() {
    final map = <String, List<AutomationScenario>>{
      'heating': <AutomationScenario>[],
      'water': <AutomationScenario>[],
      'safety': <AutomationScenario>[],
      'ventilation': <AutomationScenario>[],
      'other': <AutomationScenario>[],
    };
    return InMemoryAutomationRepository(map);
  }

  final Map<String, List<AutomationScenario>> _store;

  @override
  List<AutomationScenario> getScenarios(String systemType) {
    return List<AutomationScenario>.from(
        _store[systemType] ?? _store['other'] ?? const <AutomationScenario>[]);
  }

  @override
  void createScenario(String systemType, AutomationScenario scenario) {
    final current = List<AutomationScenario>.from(
        _store[systemType] ?? const <AutomationScenario>[]);
    current.insert(0, scenario);
    _store[systemType] = current;
  }

  @override
  void deleteScenario(String systemType, String scenarioId) {
    final current = List<AutomationScenario>.from(
        _store[systemType] ?? const <AutomationScenario>[]);
    current.removeWhere((s) => s.id == scenarioId);
    _store[systemType] = current;
  }

  @override
  void toggleScenario(String systemType, String scenarioId, bool isEnabled) {
    final current = List<AutomationScenario>.from(
        _store[systemType] ?? const <AutomationScenario>[]);
    _store[systemType] = current
        .map((s) => s.id == scenarioId ? s.copyWith(isEnabled: isEnabled) : s)
        .toList(growable: false);
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? UiTokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? UiTokens.accent : UiTokens.muted(context),
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: UiTokens.foreground(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: UiTokens.muted(context)),
            ),
          ],
        ),
      ),
    );
  }
}
