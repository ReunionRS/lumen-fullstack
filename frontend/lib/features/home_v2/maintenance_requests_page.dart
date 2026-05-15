import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/maintenance_request_models.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';

class MaintenanceRequestsPage extends StatefulWidget {
  const MaintenanceRequestsPage({
    super.key,
    required this.auth,
  });

  final AuthService auth;

  @override
  State<MaintenanceRequestsPage> createState() => _MaintenanceRequestsPageState();
}

class _MaintenanceRequestsPageState extends State<MaintenanceRequestsPage> {
  final List<MaintenanceRequest> _items = [];
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];
  String? _selectedClientId;
  String? _selectedProjectId;
  bool _loading = true;
  String? _error;

  String _t(String ru, String udm, String en, {String? tt, String? ba}) {
    return I18n.t(ru, udm, en, tt: tt, ba: ba);
  }

  @override
  void initState() {
    super.initState();
    _loadSelectors();
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
          ..addAll(users.where((u) =>
              u.role == 'client' && u.isActive && !u.isArchived));
        _projects
          ..clear()
          ..addAll(projects);
      });
      await _loadRequests();
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRequests() async {
    try {
      final items = await widget.auth.fetchMaintenanceRequests(
        projectId: _selectedProjectId,
        clientUserId: _selectedClientId,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(items);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<ProjectSummary> _clientProjects() {
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
        title: Text(_t('Заявки', 'Заявкаос', 'Requests', tt: 'Гаризалар', ba: 'Ғаризалар')),
      ),
      body: _loading
          ? const _LoadingState()
          : _error != null
              ? _EmptyState(title: _t('Ошибка', 'Йӧслык', 'Error', tt: 'Хата', ba: 'Хата'), subtitle: _error!)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _buildFilters(),
                    const SizedBox(height: 16),
                    if (_items.isEmpty)
                      _EmptyState(
                        title: _t('Нет заявок', 'Заявкаос ӧвӧл', 'No requests', tt: 'Гаризалар юк', ba: 'Ғаризалар юҡ'),
                        subtitle: _t('Новые заявки появятся здесь', 'Выль заявкаос татын луозы', 'New requests will appear here', tt: 'Яңа гаризалар монда күренәчәк', ba: 'Яңы ғаризалар бында күренәсәк'),
                      )
                    else
                      ..._items.map((item) => _RequestCard(
                            item: item,
                            onTap: () => _openEditSheet(item),
                          )),
                  ],
                ),
    );
  }

  Widget _buildFilters() {
    final projects = _clientProjects();
    return Column(
      children: [
        DropdownButtonFormField<String>(
          value: _selectedClientId,
          items: _clients
              .map((client) => DropdownMenuItem(
                    value: client.id,
                    child: Text(client.fio),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedClientId = value;
              _selectedProjectId = null;
            });
            _loadRequests();
          },
          decoration: InputDecoration(labelText: _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedProjectId,
          items: projects
              .map((project) => DropdownMenuItem(
                    value: project.id,
                    child: Text(project.constructionAddress),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() => _selectedProjectId = value);
            _loadRequests();
          },
          decoration: InputDecoration(labelText: _t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект')),
        ),
      ],
    );
  }

  void _openEditSheet(MaintenanceRequest request) {
    final specialistController =
        TextEditingController(text: request.specialistName);
    DateTime? date = request.preferredDate;
    String status = request.status;
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
                    _t('Заявка', 'Заявка', 'Request', tt: 'Гариза', ba: 'Ғариза'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: [
                      DropdownMenuItem(value: 'new', child: Text(_t('Новая', 'Выль', 'New', tt: 'Яңа', ba: 'Яңы'))),
                      DropdownMenuItem(value: 'pending', child: Text(_t('Ожидает', 'Утьёс', 'Pending', tt: 'Көтелә', ba: 'Көтөлә'))),
                      DropdownMenuItem(value: 'assigned', child: Text(_t('Назначена', 'Назначено', 'Assigned', tt: 'Билгеләнде', ba: 'Билдәләнде'))),
                      DropdownMenuItem(value: 'confirmed', child: Text(_t('Подтверждена', 'Подтвердитэм', 'Confirmed', tt: 'Расланды', ba: 'Раҫланды'))),
                      DropdownMenuItem(value: 'completed', child: Text(_t('Выполнена', 'Быдтэм', 'Completed', tt: 'Үтәлде', ba: 'Үтәлде'))),
                      DropdownMenuItem(value: 'cancelled', child: Text(_t('Отменена', 'Берытскем', 'Cancelled', tt: 'Кире кагылды', ba: 'Кире ҡағылды'))),
                    ],
                    onChanged: (value) {
                      if (value != null) setModalState(() => status = value);
                    },
                    decoration: InputDecoration(labelText: _t('Статус', 'Статус', 'Status', tt: 'Статус', ba: 'Статус')),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: _t('Дата визита', 'Визит нунал', 'Visit date', tt: 'Килү датасы', ba: 'Килеү датаһы'),
                    value: date,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date ?? DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 5),
                      );
                      if (picked == null) return;
                      setModalState(() => date = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: specialistController,
                    decoration: InputDecoration(labelText: _t('Специалист', 'Специалист', 'Specialist', tt: 'Белгеч', ba: 'Белгес')),
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
                                final updated =
                                    await widget.auth.updateMaintenanceRequest(
                                  requestId: request.id,
                                  status: status,
                                  specialistName:
                                      specialistController.text.trim(),
                                  preferredDate: date,
                                );
                                if (!mounted) return;
                                setState(() {
                                  final idx = _items.indexWhere(
                                      (r) => r.id == request.id);
                                  if (idx != -1) _items[idx] = updated;
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
                                if (mounted) setModalState(() => saving = false);
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
                          : Text(_t('Сохранить', 'Утчаны', 'Save', tt: 'Сакларга', ba: 'Һаҡларға')),
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
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.onTap,
  });

  final MaintenanceRequest item;
  final VoidCallback onTap;

  String _statusLabel(String status) {
    switch (status) {
      case 'assigned':
        return I18n.t('Назначена', 'Назначено', 'Assigned', tt: 'Билгеләнде', ba: 'Билдәләнде');
      case 'confirmed':
        return I18n.t('Подтверждена', 'Подтвердитэм', 'Confirmed', tt: 'Расланды', ba: 'Раҫланды');
      case 'completed':
        return I18n.t('Выполнена', 'Быдтэм', 'Completed', tt: 'Үтәлде', ba: 'Үтәлде');
      case 'cancelled':
        return I18n.t('Отменена', 'Берытскем', 'Cancelled', tt: 'Кире кагылды', ba: 'Кире ҡағылды');
      case 'pending':
        return I18n.t('Ожидает', 'Утьёс', 'Pending', tt: 'Көтелә', ba: 'Көтөлә');
      case 'new':
      default:
        return I18n.t('Новая', 'Выль', 'New', tt: 'Яңа', ba: 'Яңы');
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = item.preferredDate == null
        ? I18n.t('Без даты', 'Нуналтэк', 'No date', tt: 'Дата юк', ba: 'Дата юҡ')
        : formatDateRu(item.preferredDate!.toIso8601String());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.projectAddress.isEmpty
                        ? I18n.t('Заявка', 'Заявка', 'Request', tt: 'Гариза', ba: 'Ғариза')
                        : item.projectAddress,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: UiTokens.surface(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(item.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: UiTokens.muted(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (item.systemType.isNotEmpty)
              Text(
                item.systemType,
                style: TextStyle(color: UiTokens.muted(context)),
              ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description,
                style: TextStyle(color: UiTokens.muted(context)),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              date,
              style: TextStyle(fontSize: 12, color: UiTokens.muted(context)),
            ),
          ],
        ),
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
  final DateTime? value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null
            ? I18n.t('Не выбрано', 'Уг бырйымтэ', 'Not selected', tt: 'Сайланмады', ba: 'Һайланманы')
            : formatDateRu(value!.toIso8601String())),
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
