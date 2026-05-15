import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/journal_models.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
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
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final List<JournalEntry> _entries = [];
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];

  String? _selectedClientId;
  String? _selectedProjectId;
  JournalEntryType? _filter;

  bool _loadingSelectors = false;
  bool _loadingEntries = false;
  String? _error;

  bool get _isClient => widget.role == 'client';
  bool get _needsSelection =>
      !_isClient && (_selectedClientId == null || _selectedProjectId == null);
  String? get _activeProjectId => _isClient ? widget.projectId : _selectedProjectId;

  String _t(String ru, String udm, String en, {String? tt, String? ba}) {
    return I18n.t(ru, udm, en, tt: tt, ba: ba);
  }

  @override
  void initState() {
    super.initState();
    if (_isClient) {
      _selectedProjectId = widget.projectId;
      _loadEntries();
    } else {
      _loadSelectors();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UiTokens.background(context),
      appBar: AppBar(
        title: Text(I18n.t('Журнал дома', 'Коркалэн журналэз', 'House journal')),
        backgroundColor: UiTokens.background(context),
        foregroundColor: UiTokens.foreground(context),
        elevation: 0,
      ),
      floatingActionButton: !_needsSelection
          ? FloatingActionButton.extended(
              onPressed: _openAddEntrySheet,
              icon: const Icon(Icons.add),
              label: Text(I18n.t('Добавить', 'Сутыны', 'Add')),
              backgroundColor: UiTokens.accent,
              foregroundColor: Colors.black,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingSelectors || _loadingEntries) return const _LoadingState();
    if (_error != null) return _EmptyState(title: I18n.t('Ошибка', 'Йӧслык', 'Error'), subtitle: _error!);
    if (_needsSelection) return _buildSelectionView();
    if (_activeProjectId == null || _activeProjectId!.isEmpty) {
      return _EmptyState(
        title: I18n.t('Объект не выбран', 'Объект уг бырйы', 'Project not selected'),
        subtitle: I18n.t('Выберите объект, чтобы видеть журнал', 'Журналез адӟыны объект бырйы', 'Choose a project to view journal'),
      );
    }

    final filtered = _filter == null
        ? _entries
        : _entries
            .where((e) => e.entryType == _filter)
            .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        if (_isClient && widget.projectLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
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
            padding: const EdgeInsets.only(bottom: 4),
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
        _buildFilters(),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _EmptyState(
            title: _t('Нет записей', 'Записьёс ӧвӧл', 'No entries', tt: 'Язмалар юк', ba: 'Яҙмалар юҡ'),
            subtitle: _t('Добавьте первую запись в журнал', 'Журналэ нырысь запись суты', 'Add your first journal entry', tt: 'Журналга беренче язманы өстәгез', ba: 'Журналға беренсе яҙманы өҫтәгеҙ'),
          )
        else
          ...filtered.map((entry) => _EntryCard(
                entry: entry,
                resolveFileUrl: widget.auth.resolveFileUrl,
                onTapPhoto: entry.photoUrl.isEmpty
                    ? null
                    : () => _showPhoto(entry.photoUrl),
              )),
      ],
    );
  }

  Widget _buildFilters() {
    final items = <JournalEntryType?>[
      null,
      JournalEntryType.repair,
      JournalEntryType.breakdown,
      JournalEntryType.maintenance,
      JournalEntryType.modernization,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final isActive = _filter == item;
          final label = item == null ? _t('Все', 'Ваньмыз', 'All', tt: 'Барысы', ba: 'Барыһы') : item.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label),
              selected: isActive,
              onSelected: (_) => setState(() => _filter = item),
              selectedColor: UiTokens.accent.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isActive
                    ? UiTokens.accent
                    : UiTokens.muted(context),
              ),
              side: BorderSide(
                color: isActive ? UiTokens.accent : UiTokens.border(context),
              ),
              backgroundColor: UiTokens.card(context),
            ),
          );
        }).toList(),
      ),
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
              u.role == 'client' && u.isActive && !u.isArchived));
        _projects
          ..clear()
          ..addAll(projects);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingSelectors = false);
    }
  }

  Future<void> _loadEntries() async {
    final projectId = _activeProjectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() {
        _entries.clear();
        _loadingEntries = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loadingEntries = true;
      _error = null;
    });
    try {
      final items = await widget.auth.fetchJournalEntries(projectId: projectId);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(items);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingEntries = false);
    }
  }

  List<ProjectSummary> _clientProjects() {
    if (_selectedClientId == null) return const [];
    return _projects
        .where((p) => p.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  Widget _buildSelectionView() {
    if (_clients.isEmpty) {
      return _EmptyState(
        title: _t('Нет клиентов', 'Клиентъёс ӧвӧл', 'No clients', tt: 'Клиентлар юк', ba: 'Клиенттар юҡ'),
        subtitle: _t('Сначала добавьте клиента в системе', 'Клиентез системае суты', 'Add a client to the system first', tt: 'Башта системага клиент өстәгез', ba: 'Башта системаға клиент өҫтәгеҙ'),
      );
    }
    final projects = _clientProjects();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Text(
          _t('Сначала выберите клиента', 'Клиентез башта бырйы', 'Select a client first', tt: 'Башта клиентны сайлагыз', ba: 'Башта клиентты һайлағыҙ'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: UiTokens.foreground(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t('После выбора клиента и объекта данные будут загружены', 'Клиент но объект бырйыса бере, даннайос грузитчозы', 'Data will load after selecting client and project', tt: 'Клиент һәм объект сайлангач, мәгълүмат йөкләнәчәк', ba: 'Клиент һәм объект һайланғас, мәғлүмәт йөкләнә'),
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
                    .map((client) => DropdownMenuItem(
                          value: client.id,
                          child: Text(client.fio),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClientId = value;
                    _selectedProjectId = null;
                    _entries.clear();
                  });
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
                  _loadEntries();
                },
                decoration: InputDecoration(labelText: _t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openAddEntrySheet() {
    final descriptionController = TextEditingController();
    final specialistController = TextEditingController();
    JournalEntryType type = JournalEntryType.repair;
    DateTime date = DateTime.now();
    PlatformFile? photoFile;
    String? photoPath;
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
                    _t('Новая запись', 'Выль запись', 'New entry', tt: 'Яңа язма', ba: 'Яңы яҙма'),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<JournalEntryType>(
                    value: type,
                    items: JournalEntryType.values
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setModalState(() => type = value);
                    },
                    decoration: InputDecoration(labelText: _t('Тип', 'Тип', 'Type', tt: 'Төр', ba: 'Төр')),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: _t('Дата', 'Нунал', 'Date', tt: 'Дата', ba: 'Дата'),
                    value: date,
                    onPick: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(date.year - 2),
                        lastDate: DateTime(date.year + 5),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: _t('Описание', 'Вераськон', 'Description', tt: 'Тасвирлама', ba: 'Тасуирлама')),
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
                              photoPath = photoFile?.name;
                            });
                          },
                          icon: const Icon(Icons.photo_outlined),
                          label: Text(
                            photoPath == null ? _t('Фото', 'Суред', 'Photo', tt: 'Фото', ba: 'Фото') : _t('Выбрано', 'Бырйымтэ', 'Selected', tt: 'Сайланды', ba: 'Һайланды'),
                          ),
                        ),
                      ),
                      if (photoPath != null) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () => setModalState(() {
                            photoFile = null;
                            photoPath = null;
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
                              final projectId = _activeProjectId;
                              if (projectId == null || projectId.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t('Сначала выберите объект', 'Башта объект бырйы', 'Select project first', tt: 'Башта объектны сайлагыз', ba: 'Башта объектты һайлағыҙ')),
                                  ),
                                );
                                return;
                              }
                              final description =
                                  descriptionController.text.trim();
                              if (description.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t('Введите описание', 'Вераськон пыртӥське', 'Enter description', tt: 'Тасвирлама кертегез', ba: 'Тасуирлама индерегеҙ')),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                String photoUrl = '';
                                if (photoFile != null) {
                                  photoUrl = await widget.auth
                                      .uploadJournalPhoto(file: photoFile!);
                                }
                                final entry =
                                    await widget.auth.createJournalEntry(
                                  projectId: projectId,
                                  entryType: type,
                                  description: description,
                                  specialist:
                                      specialistController.text.trim(),
                                  entryDate: date,
                                  photoUrl: photoUrl,
                                );
                                if (!mounted) return;
                                setState(() => _entries.insert(0, entry));
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

  void _showPhoto(String photoUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              widget.auth.resolveFileUrl(photoUrl),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  String _clientLabel(String id) {
    final match = _clients.where((c) => c.id == id);
    if (match.isEmpty) return _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент');
    return '${_t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')}: ${match.first.fio}';
  }

  String _projectLabel(String id) {
    final match = _projects.where((p) => p.id == id);
    if (match.isEmpty) return _t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект');
    return '${_t('Объект', 'Объект', 'Project', tt: 'Объект', ba: 'Объект')}: ${match.first.constructionAddress}';
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.resolveFileUrl,
    this.onTapPhoto,
  });

  final JournalEntry entry;
  final String Function(String) resolveFileUrl;
  final VoidCallback? onTapPhoto;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: entry.entryType.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.entryType.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: entry.entryType.color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatDateRu(entry.entryDate.toIso8601String()),
                style: TextStyle(
                  fontSize: 12,
                  color: UiTokens.muted(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          if (entry.specialist.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${I18n.t('Специалист', 'Специалист', 'Specialist', tt: 'Белгеч', ba: 'Белгес')}: ${entry.specialist}',
              style: TextStyle(color: UiTokens.muted(context)),
            ),
          ],
          if (entry.photoUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onTapPhoto,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  resolveFileUrl(entry.photoUrl),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
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
