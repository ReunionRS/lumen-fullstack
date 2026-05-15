import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/formatters.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';
import 'stage_details_page.dart';
import 'status_badge.dart';

class ConstructionPage extends StatefulWidget {
  const ConstructionPage({
    super.key,
    required this.details,
    required this.auth,
    required this.role,
    required this.onUpdated,
  });

  final ProjectDetails? details;
  final AuthService auth;
  final String role;
  final Future<void> Function() onUpdated;

  @override
  State<ConstructionPage> createState() => _ConstructionPageState();
}

class _ConstructionPageState extends State<ConstructionPage> {
  bool _savingStage = false;
  final List<AppUser> _clients = [];
  final List<ProjectSummary> _projects = [];
  String? _selectedClientId;
  String? _selectedProjectId;
  ProjectDetails? _adminDetails;
  bool _loadingSelectors = false;
  bool _loadingDetails = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.role != 'client') {
      _loadSelectors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = widget.role == 'client';
    final info = isClient ? widget.details : _adminDetails;
    final stages = info?.stages ?? const <ProjectStage>[];
    final completedCount =
        stages.where((s) => s.status == 'completed').length;
    final inProgressCount =
        stages.where((s) => s.status == 'in_progress').length;
    final plannedCount =
        stages.where((s) => s.status == 'not_started').length;
    final overallProgress =
        stages.isEmpty ? 0 : ((completedCount / stages.length) * 100).round();

    if (!isClient) {
      if (_loadingSelectors || _loadingDetails) {
        return const _LoadingState();
      }
      if (_error != null) {
        return _EmptyState(title: I18n.t('Ошибка', 'Йӧслык', 'Error'), subtitle: _error!);
      }
      if (_selectedClientId == null || _selectedProjectId == null) {
        return _buildSelectionView();
      }
    }

    if (!isClient && info == null) {
      return _EmptyState(
        title: I18n.t('Объект не найден', 'Объект уг шедьты', 'Project not found'),
        subtitle: I18n.t('Попробуйте выбрать другой объект', 'Мукет объект бырйылэ', 'Try selecting another project'),
      );
    }

    return Container(
      color: UiTokens.background(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 88),
        children: [
          if (!isClient)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectionLabel(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: UiTokens.muted(context),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _resetSelection,
                  child: Text(I18n.t('Сменить', 'Вошттыны', 'Change')),
                ),
              ],
            ),
          if (!isClient) const SizedBox(height: 6),
          Text(
            I18n.t('Строительство', 'Лэсьтон', 'Construction'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            info?.constructionAddress.isNotEmpty == true
                ? info!.constructionAddress
                : I18n.t('Дом', 'Корка', 'House'),
            style: TextStyle(fontSize: 12, color: UiTokens.muted(context)),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      I18n.t('Общий прогресс', 'Огъя прогресс', 'Overall progress'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: UiTokens.foreground(context),
                      ),
                    ),
                    Text(
                      '$overallProgress%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: UiTokens.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: overallProgress / 100,
                    backgroundColor: UiTokens.surface(context),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(UiTokens.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _ProgressChip(
                      color: const Color(0xFF2FCB7A),
                      label: '$completedCount готово',
                      icon: Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 10),
                    _ProgressChip(
                      color: const Color(0xFFF5A524),
                      label: '$inProgressCount в работе',
                      icon: Icons.timelapse,
                    ),
                    const SizedBox(width: 10),
                    _ProgressChip(
                      color: const Color(0xFF64748B),
                      label: '$plannedCount впереди',
                      icon: Icons.schedule,
                    ),
                  ],
                ),
              ],
            ),
            ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.t('Паспорт строительства', 'Лэсьтон паспорт', 'Construction passport'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.foreground(context),
                ),
              ),
              if (!isClient && info != null)
                IconButton(
                  onPressed: () => _openEditPassport(info),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: I18n.t('Редактировать', 'Вошттыны', 'Edit'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PassportItem(
                    label: 'Адрес', value: info?.constructionAddress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PassportItem(
                        label: 'Площадь',
                        value: info == null ? null : '${info.areaSqm} м²',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PassportItem(
                        label: 'Тип',
                        value: info?.projectType,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PassportItem(
                        label: 'Этажей',
                        value:
                            info == null ? null : info.floors.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PassportItem(
                        label: 'Материал',
                        value: info?.materials,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                I18n.t('Этапы строительства', 'Лэсьтон этапъёс', 'Construction stages'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.foreground(context),
                ),
              ),
              if (!isClient)
                TextButton.icon(
                  onPressed: _savingStage ? null : _openAddStage,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(I18n.t('Добавить', 'Сутыны', 'Add')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (stages.isEmpty)
            Text(
              I18n.t('Этапы пока не добавлены', 'Этапъёс али уг сутэ', 'No stages yet'),
              style: TextStyle(color: UiTokens.muted(context)),
            )
          else
            Column(
              children: List.generate(stages.length, (index) {
                final stage = stages[index];
                final tone = switch (stage.status) {
                  'completed' => StatusTone.success,
                  'in_progress' => StatusTone.active,
                  'overdue' => StatusTone.warning,
                  _ => StatusTone.info,
                };
                final label = kStageStatusLabels[stage.status] ?? stage.status;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _openStageDetails(stage, index),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: UiTokens.card(context),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: UiTokens.cardShadow(context),
                      ),
                      child: Row(
                        children: [
                          _StageStatusIcon(tone: tone),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stage.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: UiTokens.foreground(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${stage.stageComment.isEmpty ? '—' : stage.stageComment} · ${formatDateRu(stage.plannedStart)} — ${formatDateRu(stage.plannedEnd)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: UiTokens.muted(context),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (!isClient)
                                      _StageChip(
                                        icon: Icons.photo_camera_outlined,
                                        label: 'Фото',
                                        onTap: () =>
                                            _openStageDetails(stage, index),
                                      ),
                                    _StageChip(
                                      icon: Icons.assignment_outlined,
                                      label: 'Акты',
                                      onTap: () => _openStageDetails(stage, index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(label: label, tone: tone),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  void _openStageDetails(ProjectStage stage, int index) {
    final details = widget.role == 'client' ? widget.details : _adminDetails;
    if (details == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StageDetailsPage(
          projectId: details.id,
          stageIndex: index,
          initialStage: stage,
          auth: widget.auth,
          role: widget.role,
          onUpdated: () async {
            if (widget.role == 'client') {
              await widget.onUpdated();
            } else {
              await _loadDetails();
            }
          },
        ),
      ),
    );
  }

  void _openEditPassport(ProjectDetails details) {
    final addressController =
        TextEditingController(text: details.constructionAddress);
    final areaController =
        TextEditingController(text: details.areaSqm.toString());
    final typeController = TextEditingController(text: details.projectType);
    final floorsController =
        TextEditingController(text: details.floors.toString());
    final materialsController = TextEditingController(text: details.materials);
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
                  color: UiTokens.card(context),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Редактировать паспорт',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: UiTokens.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: 'Адрес'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: areaController,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Площадь (м²)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: typeController,
                        decoration: const InputDecoration(labelText: 'Тип'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: floorsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Этажей'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: materialsController,
                        decoration:
                            const InputDecoration(labelText: 'Материал'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                setModalState(() => saving = true);
                                try {
                                  await widget.auth.updateProject(
                                    details.id,
                                    {
                                      'constructionAddress':
                                          addressController.text.trim(),
                                      'areaSqm': num.tryParse(
                                              areaController.text.trim()) ??
                                          details.areaSqm,
                                      'projectType':
                                          typeController.text.trim().isEmpty
                                              ? details.projectType
                                              : typeController.text.trim(),
                                      'floors': int.tryParse(
                                              floorsController.text.trim()) ??
                                          details.floors,
                                      'materials': materialsController
                                              .text.trim().isEmpty
                                          ? details.materials
                                          : materialsController.text.trim(),
                                    },
                                  );
                                  await widget.onUpdated();
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e
                                            .toString()
                                            .replaceFirst('Exception: ', ''),
                                      ),
                                    ),
                                  );
                                } finally {
                                  if (context.mounted) {
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
                            : const Text('Сохранить'),
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

  void _openAddStage() {
    final details = widget.role == 'client' ? widget.details : _adminDetails;
    if (details == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите объект')),
      );
      return;
    }

    final nameController = TextEditingController(text: kConstructionStages[0]);
    final responsibleController = TextEditingController();
    final descriptionController = TextEditingController();
    String status = 'not_started';
    DateTime? startDate;
    DateTime? endDate;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Новый этап',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: nameController.text,
                    items: kConstructionStages
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => nameController.text = value);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Этап',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: responsibleController,
                    decoration:
                        const InputDecoration(labelText: 'Ответственный'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(labelText: 'Описание работ'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Начало',
                          value: startDate,
                          onPick: () async {
                            final picked = await _pickDate(context, startDate);
                            if (picked == null) return;
                            setModalState(() => startDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'Окончание',
                          value: endDate,
                          onPick: () async {
                            final picked = await _pickDate(context, endDate);
                            if (picked == null) return;
                            setModalState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    items: kStageStatusLabels.keys
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(kStageStatusLabels[e] ?? e),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => status = value);
                    },
                    decoration: const InputDecoration(labelText: 'Статус'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _savingStage
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) return;
                            await _saveStage(
                              details: details,
                              name: nameController.text.trim(),
                              responsible: responsibleController.text.trim(),
                              description: descriptionController.text.trim(),
                              status: status,
                              start: startDate,
                              end: endDate,
                            );
                            if (mounted) Navigator.of(context).pop();
                          },
                    child: _savingStage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Сохранить этап'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      responsibleController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _saveStage({
    required ProjectDetails details,
    required String name,
    required String responsible,
    required String description,
    required String status,
    DateTime? start,
    DateTime? end,
  }) async {
    setState(() => _savingStage = true);
    try {
      final stage = ProjectStage(
        id: 'stage-${details.stages.length + 1}',
        name: name,
        status: status,
        plannedStart: _formatIsoDate(start),
        plannedEnd: _formatIsoDate(end),
        stageComment: responsible,
        comments: description,
        photoUrls: const [],
      );

      final newStages = [...details.stages, stage];
      await widget.auth.updateProject(
        details.id,
        details.toPatchJson(stagesOverride: newStages),
      );
      if (widget.role == 'client') {
        await widget.onUpdated();
      } else {
        await _loadDetails();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _savingStage = false);
      }
    }
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
          ..addAll(
            users.where((u) => u.role == 'client' && u.isActive && !u.isArchived),
          );
        _projects
          ..clear()
          ..addAll(projects);
      });
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = 'Сессия истекла. Войдите снова.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingSelectors = false);
    }
  }

  Future<void> _loadDetails() async {
    final projectId = _selectedProjectId;
    if (projectId == null || projectId.isEmpty) {
      setState(() => _adminDetails = null);
      return;
    }
    setState(() {
      _loadingDetails = true;
      _error = null;
    });
    try {
      final details = await widget.auth.fetchProjectById(projectId);
      if (!mounted) return;
      setState(() => _adminDetails = details);
    } on UnauthorizedException {
      if (!mounted) return;
      setState(() => _error = 'Сессия истекла. Войдите снова.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  List<ProjectSummary> _clientProjects() {
    if (_selectedClientId == null) return const [];
    return _projects
        .where((p) => p.clientUserId == _selectedClientId)
        .toList(growable: false);
  }

  void _resetSelection() {
    setState(() {
      _selectedClientId = null;
      _selectedProjectId = null;
      _adminDetails = null;
    });
  }

  String _selectionLabel() {
    final client = _clients.firstWhere(
      (c) => c.id == _selectedClientId,
      orElse: () => const AppUser(
        id: '',
        fio: 'Клиент',
        email: '',
        role: 'client',
      ),
    );
    final project = _projects.firstWhere(
      (p) => p.id == _selectedProjectId,
      orElse: () => ProjectSummary(
        id: '',
        clientFio: '',
        constructionAddress: 'Объект',
        thumbnailUrl: '',
        status: '',
        startDate: '',
        plannedEndDate: '',
        progress: 0,
      ),
    );
    return 'Клиент: ${client.fio} • Объект: ${project.constructionAddress}';
  }

  Widget _buildSelectionView() {
    if (_clients.isEmpty) {
      return _EmptyState(
        title: 'Нет клиентов',
        subtitle: 'Сначала добавьте клиента в системе',
      );
    }

    final projects = _clientProjects();
    return Container(
      color: UiTokens.background(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          Text(
            'Сначала выберите клиента',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'После выбора клиента и объекта данные будут загружены',
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
                      _adminDetails = null;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Клиент'),
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
                    _loadDetails();
                  },
                  decoration: const InputDecoration(labelText: 'Объект'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(
        color: UiTokens.accent,
      ),
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

class _ProgressChip extends StatelessWidget {
  const _ProgressChip({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: UiTokens.muted(context)),
        ),
      ],
    );
  }
}

class _PassportItem extends StatelessWidget {
  const _PassportItem({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: UiTokens.muted(context)),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: UiTokens.foreground(context),
          ),
        ),
      ],
    );
  }
}

class _StageStatusIcon extends StatelessWidget {
  const _StageStatusIcon({required this.tone});

  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StatusTone.success => const Color(0xFF2FCB7A),
      StatusTone.active => const Color(0xFFF5A524),
      StatusTone.warning => const Color(0xFFE11D48),
      _ => const Color(0xFFCBD5E1),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check,
        size: 18,
        color: color,
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: UiTokens.surface(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: UiTokens.muted(context)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: UiTokens.muted(context)),
            ),
          ],
        ),
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
