import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";

import "../../core/formatters.dart";
import "../../core/i18n.dart";
import "../../core/ui_tokens.dart";
import "../../models/maintenance_models.dart";
import "../../models/project_models.dart";
import "../../models/session_models.dart";
import "../../models/user_models.dart";
import "../../services/auth_service.dart";

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({
    super.key,
    required this.auth,
    required this.role,
    this.projectId,
    this.projectLabel,
  });

  final AuthService auth;
  final String role;
  final String? projectId;
  final String? projectLabel;

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  final List<MaintenanceTask> _tasks = [];
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];
  String? _selectedClientId;
  String? _selectedProjectId;
  String? _systemFilter;
  bool _loadingSelectors = false;
  bool _loadingTasks = false;
  String? _error;

  bool get _isClient => widget.role == "client";
  String? get _activeProjectId => _isClient ? widget.projectId : _selectedProjectId;
  bool get _needsSelection =>
      !_isClient && (_selectedClientId == null || _selectedProjectId == null);

  String _t(String ru, String udm, String en, {String? tt, String? ba}) {
    return I18n.t(ru, udm, en, tt: tt, ba: ba);
  }

  @override
  void initState() {
    super.initState();
    if (_isClient) {
      _selectedProjectId = widget.projectId;
      _loadTasks();
    } else {
      _loadSelectors();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: _MaintenanceScaffold(
        title: I18n.t("Плановое обслуживание", "Планлы обслуживание", "Scheduled maintenance"),
        floatingActionButton: !_isClient && !_needsSelection
            ? FloatingActionButton.extended(
                onPressed: _openAddTaskSheet,
                icon: const Icon(Icons.add),
                label: Text(I18n.t("Добавить", "Сутыны", "Add")),
                backgroundColor: UiTokens.accent,
                foregroundColor: Colors.black,
              )
            : null,
        body: TabBarView(
          children: [
            _buildSystemsTab(),
            _buildCalendarTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemsTab() {
    if (_loadingSelectors || _loadingTasks) return const _LoadingState();
    if (_error != null) return _EmptyState(title: I18n.t("Ошибка", "Йӧслык", "Error", tt: "Хата", ba: "Хата"), subtitle: _error!);
    if (_needsSelection) return _buildSelectionView();
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: I18n.t("Объект не выбран", "Объект уг бырйы", "Project not selected"),
        subtitle: I18n.t("Выберите объект, чтобы видеть обслуживание", "Обслуживаниеез адӟыны объект бырйы", "Choose a project to view maintenance"),
      );
    }

    final summaries = _buildSystemSummaries();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (_isClient && widget.projectLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.projectLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UiTokens.muted(context),
              ),
            ),
          ),
        _buildSystemFilters(),
        const SizedBox(height: 12),
        if (summaries.isEmpty)
          _EmptyState(
            title: _t("Нет систем", "Системаос ӧвӧл", "No systems", tt: "Системалар юк", ba: "Системалар юҡ"),
            subtitle: _t("Добавьте плановое обслуживание", "Планлы обслуживание суты", "Add scheduled maintenance", tt: "Планлы хезмәт өстәгез", ba: "Планлы хеҙмәт өҫтәгеҙ"),
          )
        else
          ...summaries.map(
            (summary) => _SystemCard(
              summary: summary,
              isClient: _isClient,
              onRequest: _isClient ? () => _openRequestSheet(summary) : null,
            ),
          ),
      ],
    );
  }

  Widget _buildCalendarTab() {
    if (_loadingSelectors || _loadingTasks) return const _LoadingState();
    if (_error != null) return _EmptyState(title: _t("Ошибка", "Йӧслык", "Error", tt: "Хата", ba: "Хата"), subtitle: _error!);
    if (_needsSelection) return _buildSelectionView();
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: _t("Объект не выбран", "Объект уг бырйы", "Project not selected", tt: "Объект сайланмаган", ba: "Объект һайланмаған"),
        subtitle: _t("Выберите объект, чтобы видеть календарь", "Календарьез адӟыны объект бырйы", "Select project to view calendar", tt: "Календарь өчен объект сайлагыз", ba: "Календарҙы күреү өсөн объект һайлағыҙ"),
      );
    }

    final grouped = _groupByDate(
      _filteredTasks
          .where((t) => t.status == MaintenanceStatus.scheduled)
          .toList(growable: false),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (_isClient && widget.projectLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              widget.projectLabel!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UiTokens.muted(context),
              ),
            ),
          ),
        if (!_isClient && _selectedClientId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _clientLabel(_selectedClientId!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UiTokens.muted(context),
              ),
            ),
          ),
        if (!_isClient && _selectedProjectId != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _projectLabel(_selectedProjectId!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UiTokens.muted(context),
              ),
            ),
          ),
        _buildSystemFilters(),
        const SizedBox(height: 12),
        if (grouped.isEmpty)
          _EmptyState(
            title: _t("Нет задач", "Ужъёс ӧвӧл", "No tasks", tt: "Биремнәр юк", ba: "Бурыстар юҡ"),
            subtitle: _t("Добавьте плановое обслуживание", "Планлы обслуживание суты", "Add scheduled maintenance", tt: "Планлы хезмәт өстәгез", ba: "Планлы хеҙмәт өҫтәгеҙ"),
          )
        else
          ...grouped.entries.map((entry) {
            return _DateGroup(
              date: entry.key,
              tasks: entry.value,
              isAdmin: !_isClient,
              onComplete: _markCompleted,
              resolveFileUrl: widget.auth.resolveFileUrl,
              onDelete: !_isClient ? _confirmDelete : null,
            );
          }),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    if (_loadingSelectors || _loadingTasks) return const _LoadingState();
    if (_error != null) return _EmptyState(title: _t("Ошибка", "Йӧслык", "Error", tt: "Хата", ba: "Хата"), subtitle: _error!);
    if (_needsSelection) return _buildSelectionView();
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: _t("Объект не выбран", "Объект уг бырйы", "Project not selected", tt: "Объект сайланмаган", ba: "Объект һайланмаған"),
        subtitle: _t("Выберите объект, чтобы видеть задачи", "Ужъёсез адӟыны объект бырйы", "Select project to view tasks", tt: "Биремнәрне күрү өчен объект сайлагыз", ba: "Бурыстарҙы күреү өсөн объект һайлағыҙ"),
      );
    }

    final upcoming = _filteredTasks
        .where((t) => t.status == MaintenanceStatus.scheduled)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        if (upcoming.isEmpty)
          _EmptyState(
            title: _t("Нет ближайших работ", "Матын ужъёс ӧвӧл", "No upcoming works", tt: "Якын эшләр юк", ba: "Яҡын эштәр юҡ"),
            subtitle: _t("Плановые работы не назначены", "Планлы ужъёс уг назначить каро", "No scheduled works assigned", tt: "Планлы эшләр билгеләнмәгән", ba: "Планлы эштәр билдәләнмәгән"),
          )
        else
          ...upcoming.map(
            (task) => _TaskCard(
              task: task,
              isAdmin: !_isClient,
              onComplete: _markCompleted,
              resolveFileUrl: widget.auth.resolveFileUrl,
              onDelete: !_isClient ? () => _confirmDelete(task) : null,
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingSelectors || _loadingTasks) return const _LoadingState();
    if (_error != null) return _EmptyState(title: _t("Ошибка", "Йӧслык", "Error", tt: "Хата", ba: "Хата"), subtitle: _error!);
    if (_needsSelection) return _buildSelectionView();
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: _t("Объект не выбран", "Объект уг бырйы", "Project not selected", tt: "Объект сайланмаган", ba: "Объект һайланмаған"),
        subtitle: _t("Выберите объект, чтобы видеть историю", "Историяез адӟыны объект бырйы", "Select project to view history", tt: "Тарихны күрү өчен объект сайлагыз", ba: "Тарихты күреү өсөн объект һайлағыҙ"),
      );
    }

    final history = _filteredTasks
        .where((t) => t.status != MaintenanceStatus.scheduled)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        _buildSystemFilters(),
        const SizedBox(height: 12),
        if (history.isEmpty)
          _EmptyState(
            title: _t("История пуста", "История пуш", "History is empty", tt: "Тарих буш", ba: "Тарих буш"),
            subtitle: _t("Пока нет завершенных работ", "Быдтэм ужъёс али ӧвӧл", "No completed works yet", tt: "Әлегә тәмамланган эшләр юк", ba: "Әлегә тамамланған эштәр юҡ"),
          )
        else
          ...history.map(
            (task) => _TaskCard(
              task: task,
              isAdmin: !_isClient,
              onComplete: _markCompleted,
              resolveFileUrl: widget.auth.resolveFileUrl,
              onDelete: !_isClient ? () => _confirmDelete(task) : null,
            ),
          ),
      ],
    );
  }

  Future<void> _loadSelectors() async {
    setState(() {
      _loadingSelectors = true;
      _error = null;
    });
    try {
      final users = await widget.auth.fetchUsers();
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() {
        _clients
          ..clear()
          ..addAll(users.where((u) =>
              u.role == "client" && u.isActive && !u.isArchived));
        _projects
          ..clear()
          ..addAll(projects);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t("Сессия истекла. Войдите снова.", "Сессия быдэ. Вновь пыры.", "Session expired. Sign in again.", tt: "Сессия тәмамланды. Кабат керегез.", ba: "Сессия тамамланды. Ҡабат инегеҙ."));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loadingSelectors = false);
    }
  }

  Future<void> _loadTasks() async {
    final projectId = _activeProjectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _tasks.clear();
        _loadingTasks = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loadingTasks = true;
      _error = null;
    });
    try {
      final items = await widget.auth.fetchMaintenanceTasks(
        projectId: projectId,
      );
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(items);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = "Сессия истекла. Войдите снова.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _loadingTasks = false);
    }
  }

  List<ProjectSummary> _clientProjects() {
    if (_selectedClientId == null) return const [];
    return _projects
        .where((p) => p.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  Map<DateTime, List<MaintenanceTask>> _groupByDate(List<MaintenanceTask> tasks) {
    final map = <DateTime, List<MaintenanceTask>>{};
    for (final task in tasks) {
      final key = DateTime(task.scheduledDate.year, task.scheduledDate.month, task.scheduledDate.day);
      map.putIfAbsent(key, () => []);
      map[key]!.add(task);
    }
    final entries = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return {for (final e in entries) e.key: e.value};
  }

  String _systemKey(MaintenanceTask task) {
    final raw = task.systemType.trim();
    return raw.isEmpty ? task.title : raw;
  }

  List<String> get _systemKeys {
    final set = <String>{};
    for (final task in _tasks) {
      final key = _systemKey(task);
      if (key.isNotEmpty) set.add(key);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<MaintenanceTask> get _filteredTasks {
    if (_systemFilter == null || _systemFilter!.isEmpty) return _tasks;
    return _tasks.where((t) => _systemKey(t) == _systemFilter).toList();
  }

  List<_SystemSummary> _buildSystemSummaries() {
    final map = <String, List<MaintenanceTask>>{};
    for (final task in _tasks) {
      final key = _systemKey(task);
      if (_systemFilter != null && _systemFilter!.isNotEmpty) {
        if (key != _systemFilter) continue;
      }
      map.putIfAbsent(key, () => []);
      map[key]!.add(task);
    }
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final items = <_SystemSummary>[];
    map.forEach((key, tasks) {
      final upcoming = tasks
          .where((t) => t.status == MaintenanceStatus.scheduled)
          .toList()
        ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
      final nextDate = upcoming.isEmpty ? null : upcoming.first.scheduledDate;
      final diffDays = nextDate == null
          ? null
          : nextDate
              .difference(normalizedToday)
              .inDays;
      items.add(
        _SystemSummary(
          systemName: key.isEmpty ? 'Система' : key,
          nextDate: nextDate,
          diffDays: diffDays,
          nextTaskId: upcoming.isEmpty ? '' : upcoming.first.id,
        ),
      );
    });
    items.sort((a, b) {
      final aDate = a.nextDate ?? DateTime(3000);
      final bDate = b.nextDate ?? DateTime(3000);
      return aDate.compareTo(bDate);
    });
    return items;
  }

  Widget _buildSystemFilters() {
    final keys = _systemKeys;
    if (keys.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('Все'),
            selected: _systemFilter == null || _systemFilter!.isEmpty,
            onSelected: (_) => setState(() => _systemFilter = null),
            selectedColor: UiTokens.accent.withOpacity(0.2),
            labelStyle: TextStyle(
              color: (_systemFilter == null || _systemFilter!.isEmpty)
                  ? UiTokens.accent
                  : UiTokens.muted(context),
            ),
            side: BorderSide(
              color: (_systemFilter == null || _systemFilter!.isEmpty)
                  ? UiTokens.accent
                  : UiTokens.border(context),
            ),
            backgroundColor: UiTokens.card(context),
          ),
          const SizedBox(width: 8),
          ...keys.map((key) {
            final isActive = _systemFilter == key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(key),
                selected: isActive,
                onSelected: (_) => setState(() => _systemFilter = key),
                selectedColor: UiTokens.accent.withOpacity(0.2),
                labelStyle: TextStyle(
                  color: isActive ? UiTokens.accent : UiTokens.muted(context),
                ),
                side: BorderSide(
                  color: isActive
                      ? UiTokens.accent
                      : UiTokens.border(context),
                ),
                backgroundColor: UiTokens.card(context),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    if (_clients.isEmpty) {
      return _EmptyState(
        title: "Нет клиентов",
        subtitle: "Сначала добавьте клиента в системе",
      );
    }
    final projects = _clientProjects();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          "Сначала выберите клиента",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "После выбора клиента и объекта данные будут загружены",
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
                    .map(
                      (client) => DropdownMenuItem(
                        value: client.id,
                        child: Text(client.fio),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClientId = value;
                    _selectedProjectId = null;
                    _tasks.clear();
                  });
                },
                decoration: const InputDecoration(labelText: "Клиент"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProjectId,
                items: projects
                    .map(
                      (project) => DropdownMenuItem(
                        value: project.id,
                        child: Text(project.constructionAddress),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedProjectId = value);
                  _loadTasks();
                },
                decoration: const InputDecoration(labelText: "Объект"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddTaskSheet() {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    final systemController = TextEditingController();
    DateTime date = DateTime.now();
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Новая задача",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Название"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: systemController,
                    decoration: const InputDecoration(labelText: "Система"),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: "Дата",
                    value: date,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(date.year - 1),
                        lastDate: DateTime(date.year + 5),
                      );
                      if (picked == null) return;
                      setModalState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: "Комментарий"),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Введите название")),
                                );
                                return;
                              }
                              final projectId = _activeProjectId;
                              if (projectId == null || projectId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("Сначала выберите объект")),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                final task = await widget.auth
                                    .createMaintenanceTask(
                                  projectId: projectId,
                                  title: title,
                                  scheduledDate: date,
                                  notes: notesController.text.trim(),
                                  systemType: systemController.text.trim(),
                                );
                                if (!mounted) return;
                                setState(() {
                                  _tasks.add(task);
                                });
                                Navigator.of(context).pop();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceFirst("Exception: ", "")),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setModalState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text("Сохранить"),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openRequestSheet(_SystemSummary summary) {
    final descriptionController = TextEditingController();
    DateTime preferredDate = DateTime.now();
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вызвать специалиста',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    summary.systemName,
                    style: TextStyle(color: UiTokens.muted(context)),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Желаемая дата',
                    value: preferredDate,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: preferredDate,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setModalState(() => preferredDate = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final projectId = _activeProjectId;
                              if (projectId == null || projectId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Сначала выберите объект'),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                await widget.auth.createMaintenanceRequest(
                                  projectId: projectId,
                                  taskId: summary.nextTaskId,
                                  systemType: summary.systemName,
                                  description:
                                      descriptionController.text.trim(),
                                  preferredDate: preferredDate,
                                );
                                if (!mounted) return;
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Заявка отправлена'),
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
                                if (mounted) {
                                  setModalState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Отправить'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCompleteSheet(MaintenanceTask task) {
    final specialistController =
        TextEditingController(text: task.specialistName);
    final reportController = TextEditingController(text: task.reportNotes);
    PlatformFile? photoFile;
    String? photoLabel;
    bool saving = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Закрыть обслуживание',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialistController,
                    decoration:
                        const InputDecoration(labelText: 'Специалист'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reportController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Отчет'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                            );
                            if (result == null || result.files.isEmpty) return;
                            setModalState(() {
                              photoFile = result.files.first;
                              photoLabel = photoFile?.name;
                            });
                          },
                          icon: const Icon(Icons.photo_outlined),
                          label: Text(
                            photoLabel == null ? 'Фото' : 'Выбрано',
                          ),
                        ),
                      ),
                      if (photoLabel != null) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => setModalState(() {
                            photoFile = null;
                            photoLabel = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              setModalState(() => saving = true);
                              try {
                                String reportPhotoUrl = '';
                                if (photoFile != null) {
                                  reportPhotoUrl = await widget.auth
                                      .uploadJournalPhoto(file: photoFile!);
                                }
                                final updated =
                                    await widget.auth.updateMaintenanceTask(
                                  taskId: task.id,
                                  status: MaintenanceStatus.completed,
                                  specialistName:
                                      specialistController.text.trim(),
                                  reportNotes: reportController.text.trim(),
                                  reportPhotoUrl: reportPhotoUrl,
                                );
                                if (!mounted) return;
                                setState(() {
                                  _tasks.removeWhere((t) => t.id == task.id);
                                  _tasks.add(updated);
                                });
                                Navigator.of(context).pop();
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
                                if (mounted) {
                                  setModalState(() => saving = false);
                                }
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Закрыть'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _markCompleted(MaintenanceTask task) async {
    if (_isClient) return;
    _openCompleteSheet(task);
  }

  Future<void> _confirmDelete(MaintenanceTask task) async {
    if (_isClient) return;
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить обслуживание?'),
            content: Text(task.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await widget.auth.deleteMaintenanceTask(task.id);
      if (!mounted) return;
      setState(() {
        _tasks.removeWhere((t) => t.id == task.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  String _clientLabel(String id) {
    final match = _clients.where((c) => c.id == id);
    if (match.isEmpty) return "Клиент";
    return "Клиент: ${match.first.fio}";
  }

  String _projectLabel(String id) {
    final match = _projects.where((p) => p.id == id);
    if (match.isEmpty) return "Объект";
    return "Объект: ${match.first.constructionAddress}";
  }
}

class _SystemSummary {
  const _SystemSummary({
    required this.systemName,
    required this.nextDate,
    required this.diffDays,
    required this.nextTaskId,
  });

  final String systemName;
  final DateTime? nextDate;
  final int? diffDays;
  final String nextTaskId;
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({
    required this.summary,
    required this.isClient,
    this.onRequest,
  });

  final _SystemSummary summary;
  final bool isClient;
  final VoidCallback? onRequest;

  String _statusLabel() {
    if (summary.nextDate == null) return 'Не назначено';
    if (summary.diffDays == null) return 'Не назначено';
    if (summary.diffDays! < 0) return 'Просрочено';
    if (summary.diffDays == 0) return 'Сегодня';
    if (summary.diffDays == 1) return 'Через 1 день';
    return 'Через ${summary.diffDays} дней';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = summary.nextDate == null
        ? 'Нет даты'
        : formatDateRu(summary.nextDate!.toIso8601String());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.systemName,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Следующее обслуживание: $dateLabel',
            style: TextStyle(color: UiTokens.muted(context)),
          ),
          const SizedBox(height: 4),
          Text(
            'Статус: ${_statusLabel()}',
            style: TextStyle(color: UiTokens.muted(context)),
          ),
          if (isClient && onRequest != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onRequest,
                child: const Text('Вызвать специалиста'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.tasks,
    required this.isAdmin,
    required this.onComplete,
    this.onDelete,
    this.resolveFileUrl,
  });

  final DateTime date;
  final List<MaintenanceTask> tasks;
  final bool isAdmin;
  final ValueChanged<MaintenanceTask> onComplete;
  final ValueChanged<MaintenanceTask>? onDelete;
  final String Function(String)? resolveFileUrl;

  @override
  Widget build(BuildContext context) {
    final label = formatDateRu(date.toIso8601String());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: UiTokens.muted(context),
          ),
        ),
        const SizedBox(height: 8),
        ...tasks.map(
          (task) => _TaskCard(
            task: task,
            isAdmin: isAdmin,
            onComplete: onComplete,
            resolveFileUrl: resolveFileUrl,
            onDelete: (isAdmin && onDelete != null) ? () => onDelete!(task) : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.isAdmin,
    required this.onComplete,
    this.onDelete,
    this.resolveFileUrl,
  });

  final MaintenanceTask task;
  final bool isAdmin;
  final ValueChanged<MaintenanceTask> onComplete;
  final VoidCallback? onDelete;
  final String Function(String)? resolveFileUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: task.status.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: task.status.color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: UiTokens.foreground(context),
                  ),
                ),
                if (task.systemType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.systemType,
                    style: TextStyle(color: UiTokens.muted(context)),
                  ),
                ],
                if (task.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.notes,
                    style: TextStyle(color: UiTokens.muted(context)),
                  ),
                ],
                if (task.specialistName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Специалист: ${task.specialistName}',
                    style: TextStyle(color: UiTokens.muted(context)),
                  ),
                ],
                if (task.reportNotes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.reportNotes,
                    style: TextStyle(color: UiTokens.muted(context)),
                  ),
                ],
                if (task.reportPhotoUrl.isNotEmpty && resolveFileUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      resolveFileUrl!(task.reportPhotoUrl),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  task.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: task.status.color,
                  ),
                ),
              ],
            ),
          ),
          if (isAdmin)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.status == MaintenanceStatus.scheduled)
                  TextButton(
                    onPressed: () => onComplete(task),
                    child: const Text("Выполнено"),
                  ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: UiTokens.muted(context),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(formatDateRu(value.toIso8601String())),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: UiTokens.accent),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UiTokens.background(context),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: UiTokens.foreground(context),
              ),
            ),
            const SizedBox(height: 6),
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

class _MaintenanceScaffold extends StatelessWidget {
  const _MaintenanceScaffold({
    required this.title,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: UiTokens.background(context),
        foregroundColor: UiTokens.foreground(context),
        bottom: TabBar(
          labelColor: UiTokens.foreground(context),
          unselectedLabelColor: UiTokens.muted(context),
          indicatorColor: UiTokens.accent,
          tabs: const [
            Tab(text: "Обслуживание"),
            Tab(text: "Календарь"),
            Tab(text: "История"),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
