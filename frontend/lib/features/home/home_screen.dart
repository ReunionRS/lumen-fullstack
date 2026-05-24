import 'dart:typed_data';
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../models/activity_models.dart';
import '../../models/house_catalog.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/system_models.dart';
import '../../services/auth_service.dart';
import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../home_v2/bottom_nav.dart';
import '../home_v2/construction_page.dart';
import '../home_v2/dashboard_page.dart';
import '../home_v2/documents_overview_page.dart';
import '../home_v2/finances_page.dart';
import '../home_v2/journal_page.dart';
import '../home_v2/more_sheet.dart';
import '../home_v2/notifications_page.dart';
import '../home_v2/profile_page.dart';
import '../home_v2/settings_page.dart';
import '../home_v2/support_chat_page.dart';
import '../home_v2/maintenance_page.dart';
import '../home_v2/systems_page.dart';
import '../admin/admin_panel_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.auth,
    required this.session,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  final AuthService auth;
  final AppSession session;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProjectSummary> _projects = const [];
  ProjectDetails? _constructionDetails;
  bool _loading = true;
  String? _error;
  int _tabIndex = 0;
  String? _selectedProjectId;
  bool _hasUnreadNotifications = false;
  List<ActivityItem> _recentActivity = const [];
  Timer? _systemsTimer;
  String _systemTemp = '--';
  String _systemHumidity = '--';
  String _systemEnergy = '--';
  String _systemSecurity = '--';
  bool _systemStatusOk = true;
  late final PageController _pageController;

  bool get _hasAdminAccess =>
      widget.session.role == 'admin' || widget.session.role == 'director';

  String _t(
    String ru,
    String udm,
    String en, {
    String? tt,
    String? ba,
  }) {
    switch (widget.language) {
      case AppLanguage.udm:
        return udm;
      case AppLanguage.tt:
        return tt ?? ru;
      case AppLanguage.ba:
        return ba ?? ru;
      case AppLanguage.en:
        return en;
      case AppLanguage.ru:
        return ru;
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _tabIndex);
    _loadAll();
    _startSystemsPolling();
  }

  @override
  void dispose() {
    _systemsTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _setTab(int index, {bool animated = true}) async {
    if (index == _tabIndex) return;
    if (!mounted) return;
    setState(() => _tabIndex = index);
    if (!_pageController.hasClients) return;
    if (!animated) {
      _pageController.jumpToPage(index);
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _loadAll() async {
    await _loadProjects();
    await _loadNotificationBadge();
    await _loadRecentActivity();
    await _loadDashboardSystems();
  }

  Future<void> _loadProjects() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        if (_selectedProjectId == null &&
            projects.isNotEmpty &&
            widget.session.role == 'client') {
          _selectedProjectId = projects.first.id;
        }
      });
      await _loadConstructionDetails(projects);
    } on UnauthorizedException {
      await widget.onLogout();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadNotificationBadge() async {
    try {
      final items = await widget.auth.fetchNotifications();
      if (!mounted) return;
      setState(() {
        _hasUnreadNotifications = items.any((n) => !n.isRead);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _hasUnreadNotifications = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasUnreadNotifications = false);
    }
  }

  Future<void> _loadRecentActivity() async {
    if (!_hasAdminAccess) return;
    try {
      final items = await widget.auth.fetchActivity(limit: 6);
      if (!mounted) return;
      setState(() => _recentActivity = items);
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _recentActivity = const []);
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentActivity = const []);
    }
  }

  Future<void> _loadConstructionDetails(List<ProjectSummary> projects) async {
    if (projects.isEmpty || _selectedProjectId == null) {
      setState(() => _constructionDetails = null);
      return;
    }
    try {
      final details = await widget.auth.fetchProjectById(_selectedProjectId!);
      if (!mounted) return;
      setState(() => _constructionDetails = details);
    } catch (_) {}
  }

  Future<void> _selectProject(ProjectSummary project) async {
    setState(() => _selectedProjectId = project.id);
    await _setTab(1);
    await _loadConstructionDetails(_projects);
    await _loadDashboardSystems();
  }

  void _startSystemsPolling() {
    _systemsTimer?.cancel();
    _systemsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _loadDashboardSystems();
    });
  }

  String _formatSystemValue(SystemEntity entity) {
    final state = entity.state.trim();
    if (state.isEmpty) return '--';
    if (entity.unit.isNotEmpty) return '$state ${entity.unit}';
    return state;
  }

  Future<void> _loadDashboardSystems() async {
    if (widget.session.role != 'client') return;
    if (_selectedProjectId == null || _selectedProjectId!.isEmpty) return;
    try {
      final items = await widget.auth.fetchSystemStatus(
        projectId: _selectedProjectId,
      );
      if (!mounted) return;

      SystemEntity? temp;
      SystemEntity? humidity;
      SystemEntity? energy;
      var hasAlarm = false;

      for (final item in items) {
        final unit = item.unit.toLowerCase();
        final dc = item.deviceClass.toLowerCase();
        final state = item.state.toLowerCase();

        if (temp == null && (dc == 'temperature' || unit.contains('°c'))) {
          temp = item;
        }
        if (humidity == null && (dc == 'humidity' || unit == '%')) {
          humidity = item;
        }
        if (energy == null &&
            (dc == 'energy' ||
                dc == 'power' ||
                unit.contains('kwh') ||
                unit.contains('kw') ||
                unit.contains('вт'))) {
          energy = item;
        }
        if ((dc == 'smoke' || dc == 'moisture') &&
            (state == 'on' || state == 'detected' || state == 'true')) {
          hasAlarm = true;
        }
      }

      setState(() {
        _systemTemp = temp == null ? '--' : _formatSystemValue(temp);
        _systemHumidity =
            humidity == null ? '--' : _formatSystemValue(humidity);
        _systemEnergy = energy == null ? '--' : _formatSystemValue(energy);
        _systemStatusOk = !hasAlarm;
        _systemSecurity = hasAlarm
            ? _t('Тревога', 'Тревога', 'Alert', tt: 'Тревога', ba: 'Тревога')
            : _t('Норма', 'Норма', 'OK', tt: 'Норма', ba: 'Норма');
      });
    } catch (_) {
      // silently ignore dashboard telemetry errors
    }
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '$title ${_t('— скоро', '— берпум', '— coming soon', tt: '— тиздән', ba: '— тиҙҙән')}')));
  }

  void _openMoreSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MoreSheet(
        items: [
          MoreSheetItem(
            label: _t('Умный дом', 'Умной корка', 'Smart home',
                tt: 'Акыллы йорт', ba: 'Аҡыллы йорт'),
            description: _t(
                'IoT и датчики', 'IoT но датчикъёс', 'IoT and sensors',
                tt: 'IoT һәм датчиклар', ba: 'IoT һәм датчиктар'),
            icon: Icons.memory_outlined,
            onTap: () => _setTab(2),
          ),
          MoreSheetItem(
            label: _t('Обслуживание', 'Обслуживание', 'Maintenance',
                tt: 'Хезмәт күрсәтү', ba: 'Хеҙмәтләндереү'),
            description: _t(
                'Плановый сервис', 'Планлы сервис', 'Scheduled service',
                tt: 'Планлы сервис', ba: 'Планлы сервис'),
            icon: Icons.calendar_month_outlined,
            onTap: _openMaintenancePage,
          ),
          MoreSheetItem(
            label:
                _t('Журнал', 'Журнал', 'Journal', tt: 'Журнал', ba: 'Журнал'),
            description: _t('Хронология событий', 'Луон хронология', 'Timeline',
                tt: 'Вакыйгалар тарихы', ba: 'Ваҡиғалар тарихы'),
            icon: Icons.book_outlined,
            onTap: _openJournalPage,
          ),
          if (widget.session.role == 'client')
            MoreSheetItem(
              label: _t('Финансы', 'Финансъёс', 'Finances',
                  tt: 'Финанслар', ba: 'Финанстар'),
              description: _t('Расходы и статистика',
                  'Узьытонъёс но статистика', 'Expenses and stats',
                  tt: 'Чыгымнар һәм статистика', ba: 'Сығымдар һәм статистика'),
              icon: Icons.account_balance_wallet_outlined,
              onTap: _openFinancesPage,
            ),
          MoreSheetItem(
            label: _t('Уведомления', 'Уведомлениеос', 'Notifications',
                tt: 'Белдерүләр', ba: 'Хәбәрнамәләр'),
            description: _t(
                'Все уведомления', 'Вань уведомлениеос', 'All notifications',
                tt: 'Барлык белдерүләр', ba: 'Бөтә хәбәрнамәләр'),
            icon: Icons.notifications_outlined,
            onTap: _openNotificationsPage,
          ),
          MoreSheetItem(
            label: _t('Профиль', 'Профиль', 'Profile',
                tt: 'Профиль', ba: 'Профиль'),
            description: _t('Аккаунт и настройки', 'Аккаунт но кельтэтъёс',
                'Account and settings',
                tt: 'Аккаунт һәм көйләүләр', ba: 'Аккаунт һәм көйләүҙәр'),
            icon: Icons.person_outline,
            onTap: _openProfilePage,
          ),
          MoreSheetItem(
            label: _t('Настройки', 'Кельтэтъёс', 'Settings',
                tt: 'Көйләүләр', ba: 'Көйләүҙәр'),
            description: _t('Параметры приложения',
                'Приложениелэн параметръёсыз', 'App preferences',
                tt: 'Кушымта параметрлары', ba: 'Ҡушымта параметрҙары'),
            icon: Icons.settings_outlined,
            onTap: _openSettingsPage,
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final greetingName = _extractGreetingName(widget.session.fio);
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (!mounted) return;
        setState(() => _tabIndex = index);
      },
      children: [
        DashboardPage(
          projects: _projects,
          greetingName: greetingName,
          role: widget.session.role,
          canCreateProject: widget.session.role != 'client',
          onCreateProject: _openCreateProjectSheet,
          onSelectProject: _selectProject,
          onOpenNotifications: _openNotificationsPage,
          onOpenSystems: () => _setTab(2),
          onOpenConstruction: () => _setTab(1),
          onOpenDocuments: () => _setTab(3),
          onOpenMaintenance: _openMaintenancePage,
          onOpenJournal: _openJournalPage,
          onOpenFinances: widget.session.role == 'client'
              ? _openFinancesPage
              : () => _showComingSoon(_t('Финансы', 'Финансъёс', 'Finances',
                  tt: 'Финанслар', ba: 'Финанстар')),
          onOpenSupport: _openSupportChat,
          onOpenAdminPanel: _openAdminPanel,
          hasUnreadNotifications: _hasUnreadNotifications,
          recentActivity: _recentActivity,
          resolveFileUrl: widget.auth.resolveFileUrl,
          language: widget.language,
          systemStatusOk: _systemStatusOk,
          systemTemp: _systemTemp,
          systemEnergy: _systemEnergy,
          systemHumidity: _systemHumidity,
          systemSecurity: _systemSecurity,
        ),
        ConstructionPage(
          details: _constructionDetails,
          auth: widget.auth,
          role: widget.session.role,
          onUpdated: _loadProjects,
        ),
        SystemsPage(
          auth: widget.auth,
          role: widget.session.role,
          projectId: _selectedProjectId,
        ),
        DocumentsOverviewPage(
          auth: widget.auth,
          role: widget.session.role,
        ),
      ],
    );
  }

  String _extractGreetingName(String fio) {
    final trimmed = fio.trim();
    if (trimmed.isEmpty) {
      return _t('Гость', 'Куно', 'Guest', tt: 'Кунак', ba: 'Ҡунаҡ');
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      return '${parts[1]} ${parts[2]}';
    }
    if (parts.length == 2) {
      return parts[1];
    }
    return parts.first;
  }

  void _openCreateProjectSheet() {
    final addressController = TextEditingController();
    final fioController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final areaController = TextEditingController();
    final floorsController = TextEditingController();
    final estimatedCostController = TextEditingController();
    final typeController = TextEditingController();
    final materialsController = TextEditingController();
    final canBindClient = widget.session.role != 'client';
    List<ClientOption> clients = const [];
    bool loadingClients = false;
    String? clientError;
    String? clientUserId;
    String? catalogHouseId;
    DateTime? startDate;
    DateTime? endDate;
    bool saving = false;
    PlatformFile? thumbnailFile;
    Uint8List? thumbnailBytes;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (canBindClient && !loadingClients && clients.isEmpty) {
              loadingClients = true;
              widget.auth.fetchClients().then((items) {
                if (!context.mounted) return;
                setModalState(() {
                  clients = items;
                  loadingClients = false;
                });
              }).catchError((error) {
                if (!context.mounted) return;
                setModalState(() {
                  clientError =
                      error.toString().replaceFirst('Exception: ', '');
                  loadingClients = false;
                });
              });
            }
            final viewInsets = MediaQuery.of(context).viewInsets;
            final maxHeight = MediaQuery.of(context).size.height * 0.9;
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: viewInsets.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Новый объект',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      if (canBindClient) ...[
                        DropdownButtonFormField<String>(
                          value: clientUserId,
                          isExpanded: true,
                          selectedItemBuilder: (context) {
                            return [
                              const Text(
                                'Привязка к клиенту',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              ...clients.map(
                                (client) => Text(
                                  client.fio.isEmpty
                                      ? client.email
                                      : '${client.fio} · ${client.email}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ];
                          },
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Привязка к клиенту'),
                            ),
                            ...clients.map(
                              (client) => DropdownMenuItem(
                                value: client.id,
                                child: Text(
                                  client.fio.isEmpty
                                      ? client.email
                                      : '${client.fio} · ${client.email}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: loadingClients
                              ? null
                              : (value) {
                                  setModalState(() => clientUserId = value);
                                  final match = clients
                                      .where((c) => c.id == value)
                                      .toList(growable: false);
                                  if (match.isNotEmpty) {
                                    fioController.text = match.first.fio;
                                    emailController.text = match.first.email;
                                  }
                                },
                          decoration: const InputDecoration(
                              labelText: 'Клиент (привязка)'),
                        ),
                        if (loadingClients)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                        else if (clientError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              clientError!,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: fioController,
                        decoration:
                            const InputDecoration(labelText: 'ФИО клиента'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: 'Телефон'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: catalogHouseId,
                        isExpanded: true,
                        selectedItemBuilder: (context) {
                          return [
                            const Text(
                              'Не выбран',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            ...houseCatalogItems.map(
                              (item) => Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ];
                        },
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Не выбран'),
                          ),
                          ...houseCatalogItems.map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.category} · ${item.floors} эт. · ${_formatRub(item.priceRub)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: saving
                            ? null
                            : (value) {
                                HouseCatalogItem? selected;
                                for (final item in houseCatalogItems) {
                                  if (item.id == value) {
                                    selected = item;
                                    break;
                                  }
                                }
                                setModalState(() {
                                  catalogHouseId = value;
                                  if (selected != null) {
                                    areaController.text =
                                        selected.areaSqm.toStringAsFixed(0);
                                    floorsController.text =
                                        selected.floors.toString();
                                    estimatedCostController.text =
                                        selected.priceRub.toStringAsFixed(0);
                                    typeController.text = selected.category;
                                    materialsController.text =
                                        selected.materials;
                                  }
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'Проект из каталога',
                          helperText: 'Необязательно',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Адрес'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Превью объекта',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: saving
                            ? null
                            : () async {
                                final picked =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.image,
                                  allowMultiple: false,
                                  withData: true,
                                );
                                if (!context.mounted) return;
                                final file = picked?.files.first;
                                if (file == null) return;
                                setModalState(() {
                                  thumbnailFile = file;
                                  thumbnailBytes = file.bytes;
                                });
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 140,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: thumbnailBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    thumbnailBytes!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.image_outlined),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Загрузить изображение',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (thumbnailFile != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: saving
                              ? null
                              : () {
                                  setModalState(() {
                                    thumbnailFile = null;
                                    thumbnailBytes = null;
                                  });
                                },
                          child: const Text('Убрать превью'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Площадь (м²)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: floorsController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Этажность'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: estimatedCostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Ориентировочная стоимость, ₽'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: typeController,
                        decoration: const InputDecoration(labelText: 'Тип'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: materialsController,
                        decoration:
                            const InputDecoration(labelText: 'Материалы'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DateField(
                              label: 'Начало',
                              value: startDate,
                              onPick: () async {
                                final picked =
                                    await _pickDate(context, startDate);
                                if (picked == null) return;
                                if (!context.mounted) return;
                                setModalState(() => startDate = picked);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DateField(
                              label: 'План сдачи',
                              value: endDate,
                              onPick: () async {
                                final picked =
                                    await _pickDate(context, endDate);
                                if (picked == null) return;
                                if (!context.mounted) return;
                                setModalState(() => endDate = picked);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!context.mounted) return;
                                setModalState(() => saving = true);
                                try {
                                  HouseCatalogItem? selectedCatalog;
                                  for (final item in houseCatalogItems) {
                                    if (item.id == catalogHouseId) {
                                      selectedCatalog = item;
                                      break;
                                    }
                                  }
                                  final created =
                                      await widget.auth.createProject({
                                    'clientFio': fioController.text.trim(),
                                    'clientPhone': phoneController.text.trim(),
                                    'clientEmail': emailController.text.trim(),
                                    'constructionAddress':
                                        addressController.text.trim(),
                                    'clientUserId': clientUserId,
                                    'areaSqm': num.tryParse(
                                            areaController.text.trim()) ??
                                        0,
                                    'floors': int.tryParse(
                                            floorsController.text.trim()) ??
                                        0,
                                    'estimatedCost': num.tryParse(
                                            estimatedCostController.text
                                                .trim()) ??
                                        0,
                                    'projectType': typeController.text.trim(),
                                    'materials':
                                        materialsController.text.trim(),
                                    'catalogHouseId': catalogHouseId,
                                    'catalogHouseName': selectedCatalog?.name,
                                    'catalogHouseUrl': selectedCatalog?.url,
                                    'status': 'in_progress',
                                    'startDate': _formatIsoDate(startDate),
                                    'plannedEndDate': _formatIsoDate(endDate),
                                    'stages': const <Map<String, dynamic>>[],
                                  });
                                  if (thumbnailFile != null) {
                                    try {
                                      await widget.auth.uploadProjectThumbnail(
                                        projectId: created.id,
                                        file: thumbnailFile!,
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceFirst(
                                                  'Exception: ', ''),
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  }
                                  if (!mounted) return;
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  await _loadProjects();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e
                                          .toString()
                                          .replaceFirst('Exception: ', '')),
                                    ),
                                  );
                                } finally {
                                  if (mounted && context.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Создать объект'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openCreateUserSheet() {
    if (!_hasAdminAccess) return;
    final fioController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'client';
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            final maxHeight = MediaQuery.of(context).size.height * 0.9;
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(maxHeight: maxHeight),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: viewInsets.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Новый пользователь',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: fioController,
                        decoration: const InputDecoration(labelText: 'ФИО'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Пароль'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        items: kRoleLabels.entries
                            .where((entry) =>
                                entry.key != 'admin' && entry.key != 'director')
                            .map(
                              (entry) => DropdownMenuItem(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) return;
                          setModalState(() => role = value);
                        },
                        decoration: const InputDecoration(labelText: 'Роль'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!context.mounted) return;
                                setModalState(() => saving = true);
                                try {
                                  await widget.auth.createUser(
                                    fio: fioController.text.trim(),
                                    email: emailController.text.trim(),
                                    password: passwordController.text,
                                    role: role,
                                    sendWelcomeEmail: true,
                                  );
                                  if (!mounted) return;
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Пользователь создан'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e
                                          .toString()
                                          .replaceFirst('Exception: ', '')),
                                    ),
                                  );
                                } finally {
                                  if (mounted && context.mounted) {
                                    setModalState(() => saving = false);
                                  }
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Создать пользователя'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
  }

  String _formatIsoDate(DateTime? value) {
    if (value == null) return '';
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatRub(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i += 1) {
      final left = digits.length - i;
      buffer.write(digits[i]);
      if (left > 1 && left % 3 == 1) {
        buffer.write(' ');
      }
    }
    return '${buffer.toString()} ₽';
  }

  void _openProfilePage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          session: widget.session,
          auth: widget.auth,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          auth: widget.auth,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  void _openNotificationsPage() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => NotificationsPage(
              auth: widget.auth,
              role: widget.session.role,
            ),
          ),
        )
        .then((_) => _loadNotificationBadge());
  }

  void _openFinancesPage() {
    if (widget.session.role != 'client') {
      _showComingSoon('Финансы');
      return;
    }
    ProjectSummary? selected;
    if (_selectedProjectId != null) {
      for (final project in _projects) {
        if (project.id == _selectedProjectId) {
          selected = project;
          break;
        }
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FinancesPage(
          auth: widget.auth,
          projectId: selected?.id ?? _selectedProjectId,
          projectLabel: selected?.constructionAddress,
          role: widget.session.role,
        ),
      ),
    );
  }

  void _openMaintenancePage() {
    ProjectSummary? selected;
    if (_selectedProjectId != null) {
      for (final project in _projects) {
        if (project.id == _selectedProjectId) {
          selected = project;
          break;
        }
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MaintenancePage(
          auth: widget.auth,
          role: widget.session.role,
          projectId: selected?.id ?? _selectedProjectId,
          projectLabel: selected?.constructionAddress,
        ),
      ),
    );
  }

  void _openJournalPage() {
    ProjectSummary? selected;
    if (_selectedProjectId != null) {
      for (final project in _projects) {
        if (project.id == _selectedProjectId) {
          selected = project;
          break;
        }
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalPage(
          auth: widget.auth,
          role: widget.session.role,
          projectId: widget.session.role == 'client'
              ? (selected?.id ?? _selectedProjectId)
              : null,
          projectLabel: widget.session.role == 'client'
              ? selected?.constructionAddress
              : null,
        ),
      ),
    );
  }

  void _openAdminPanel() {
    if (!_hasAdminAccess) {
      _showComingSoon('Админ панель');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPanelPage(auth: widget.auth),
      ),
    );
  }

  void _openSupportChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupportPage(
          auth: widget.auth,
          role: widget.session.role,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: BottomNav(
        currentIndex: _tabIndex,
        onSelect: (index) => _setTab(index),
        onOpenMore: _openMoreSheet,
        language: widget.language,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final text = value == null ? '—' : formatDateRu(value!.toIso8601String());
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(text),
      ),
    );
  }
}
