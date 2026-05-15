import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import 'document_viewer_page.dart';
import 'status_badge.dart';

class DocumentsOverviewPage extends StatefulWidget {
  const DocumentsOverviewPage({
    super.key,
    required this.auth,
    required this.role,
  });

  final AuthService auth;
  final String role;

  @override
  State<DocumentsOverviewPage> createState() => _DocumentsOverviewPageState();
}

class _DocumentsOverviewPageState extends State<DocumentsOverviewPage> {
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<ProjectDocument> _docs = const [];
  String _category = 'all';
  List<ClientOption> _clients = const [];
  String? _clientFilterId;
  bool _loadingClients = false;
  String? _clientsError;

  bool get _isClient => widget.role == 'client';

  String _t(String ru, String udm, String en, {String? tt, String? ba}) {
    return I18n.t(ru, udm, en, tt: tt, ba: ba);
  }

  static const List<String> _docTypes = [
    'Проект',
    'Чертежи',
    'Договоры',
    'Акты',
    'Сертификаты',
    'Гарантии',
    'Инструкции',
  ];

  String _categoryLabel(String key) {
    switch (key) {
      case 'all':
        return _t('Все', 'Ваньмыз', 'All', tt: 'Барысы', ba: 'Барыһы');
      case 'Проект':
        return _t('Проект', 'Проект', 'Project', tt: 'Проект', ba: 'Проект');
      case 'Чертежи':
        return _t('Чертежи', 'Чертёжъёс', 'Drawings', tt: 'Сызымнар', ba: 'Һыҙмалар');
      case 'Договоры':
        return _t('Договоры', 'Договоръёс', 'Contracts', tt: 'Килешүләр', ba: 'Килешеүҙәр');
      case 'Акты':
        return _t('Акты', 'Актъёс', 'Acts', tt: 'Актлар', ba: 'Акттар');
      case 'Сертификаты':
        return _t('Сертификаты', 'Сертификатъёс', 'Certificates', tt: 'Сертификатлар', ba: 'Сертификаттар');
      case 'Гарантии':
        return _t('Гарантии', 'Гарантияос', 'Warranties', tt: 'Гарантияләр', ba: 'Гарантиялар');
      case 'Инструкции':
        return _t('Инструкции', 'Инструкцияос', 'Instructions', tt: 'Инструкцияләр', ba: 'Инструкциялар');
      default:
        return key;
    }
  }

  @override
  void initState() {
    super.initState();
    if (!_isClient) {
      _loadClients();
    }
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await widget.auth.fetchDocuments(
        clientUserId: _isClient ? null : _clientFilterId,
      );
      if (!mounted) return;
      setState(() => _docs = docs);
    } on UnauthorizedException {
      setState(() => _error = _t('Сессия истекла. Войдите снова.', 'Сессия быдэ. Вновь пыры.', 'Session expired. Sign in again.', tt: 'Сессия тәмамланды. Кабат керегез.', ba: 'Сессия тамамланды. Ҡабат инегеҙ.'));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadClients() async {
    setState(() {
      _loadingClients = true;
      _clientsError = null;
    });
    try {
      final clients = await widget.auth.fetchClients();
      if (!mounted) return;
      setState(() => _clients = clients);
    } catch (e) {
      if (!mounted) return;
      setState(() => _clientsError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _openUploadDocument() async {
    if (_isClient) return;
    String? selectedClientId;
    String docType = 'Проект';
    PlatformFile? selectedFile;
    bool saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return Padding(
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _t('Загрузка документа', 'Документез грузитон', 'Upload document', tt: 'Документ йөкләү', ba: 'Документ йөкләү'),
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedClientId,
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(_t('Выберите клиента', 'Клиентез бырйы', 'Select client', tt: 'Клиент сайлагыз', ba: 'Клиент һайлағыҙ')),
                        ),
                        ..._clients.map(
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
                      onChanged: _loadingClients
                          ? null
                          : (value) =>
                              setModalState(() => selectedClientId = value),
                      decoration: InputDecoration(labelText: _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент')),
                    ),
                    if (_loadingClients)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else if (_clientsError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _clientsError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: docType,
                      items: _docTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_categoryLabel(type)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => docType = value);
                      },
                      decoration: InputDecoration(
                        labelText: _t('Тип документа', 'Документлэн типез', 'Document type', tt: 'Документ төре', ba: 'Документ төрө'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const [
                            'pdf',
                            'png',
                            'jpg',
                            'jpeg',
                            'doc',
                            'docx',
                          ],
                        );
                        if (result == null || result.files.isEmpty) return;
                        setModalState(() => selectedFile = result.files.first);
                      },
                      icon: const Icon(Icons.upload_file_outlined),
                      label: Text(selectedFile?.name ?? _t('Выбрать файл', 'Файл бырйыны', 'Choose file', tt: 'Файл сайлау', ba: 'Файл һайлау')),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (selectedClientId == null ||
                                  selectedClientId!.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t('Выберите клиента', 'Клиентез бырйы', 'Select client', tt: 'Клиент сайлагыз', ba: 'Клиент һайлағыҙ')),
                                  ),
                                );
                                return;
                              }
                              if (selectedFile == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(_t('Выберите файл', 'Файл бырйыны', 'Select file', tt: 'Файл сайлагыз', ba: 'Файл һайлағыҙ')),
                                  ),
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              try {
                                await widget.auth.uploadProjectDocument(
                                  docType: docType,
                                  file: selectedFile!,
                                  clientUserId: selectedClientId,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                await _load();
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e
                                          .toString()
                                          .replaceFirst('Exception: ', ''))),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_t('Загрузить', 'Грузитны', 'Upload', tt: 'Йөкләргә', ba: 'Йөкләргә')),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<ProjectDocument> _filtered() {
    final query = _searchController.text.trim().toLowerCase();
    return _docs.where((doc) {
      if (_category != 'all') {
        final type = doc.type.toLowerCase();
        final filter = _category.toLowerCase();
        if (!type.contains(filter)) return false;
      }
      if (query.isEmpty) return true;
      return doc.name.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  StatusTone _toneForDoc(ProjectDocument doc) {
    final name = doc.name.toLowerCase();
    if (name.contains('страх')) return StatusTone.warning;
    if (doc.isPdf || doc.isDocx) return StatusTone.active;
    return StatusTone.info;
  }

  Future<void> _openDocument(ProjectDocument doc) async {
    try {
      final url = await widget.auth.documentViewUrl(
        doc.id,
        inline: !doc.isDocx,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentViewerPage(
            title: doc.name,
            fileUrl: url,
            isDocx: doc.isDocx,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filtered();
    final categories = const [
      'all',
      'Проект',
      'Чертежи',
      'Договоры',
      'Акты',
      'Сертификаты',
      'Гарантии',
      'Инструкции',
    ];

    return Container(
      color: UiTokens.background(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 88),
        children: [
          Text(
            _t('Документы', 'Документъёс', 'Documents', tt: 'Документлар', ba: 'Документтар'),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_t('Дом', 'Корка', 'Home', tt: 'Йорт', ba: 'Йорт')} · ${docs.length} ${_t('файлов', 'файлъёс', 'files', tt: 'файл', ba: 'файл')}',
            style: TextStyle(fontSize: 12, color: UiTokens.muted(context)),
          ),
          const SizedBox(height: 16),
          if (!_isClient) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 420;
                final dropdown = DropdownButtonFormField<String>(
                  value: _clientFilterId,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(_t('Все клиенты', 'Вань клиентъёс', 'All clients', tt: 'Барлык клиентлар', ba: 'Бөтә клиенттар')),
                    ),
                    ..._clients.map(
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
                  onChanged: _loadingClients
                      ? null
                      : (value) {
                          setState(() => _clientFilterId = value);
                          _load();
                        },
                  selectedItemBuilder: (context) {
                    final items = [
                      Text(_t('Все клиенты', 'Вань клиентъёс', 'All clients', tt: 'Барлык клиентлар', ba: 'Бөтә клиенттар')),
                      ..._clients.map(
                        (client) => Text(
                          client.fio.isEmpty
                              ? client.email
                              : '${client.fio} · ${client.email}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ];
                    return items
                        .map(
                          (w) => Align(
                            alignment: Alignment.centerLeft,
                            child: w,
                          ),
                        )
                        .toList(growable: false);
                  },
                  decoration: InputDecoration(
                    labelText: _t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент'),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                );
                final uploadButton = SizedBox(
                  height: 48,
                  width: isNarrow ? double.infinity : null,
                  child: FilledButton.icon(
                    onPressed: _openUploadDocument,
                    icon: const Icon(Icons.upload_outlined, size: 18),
                    label: Text(_t('Загрузить', 'Грузитны', 'Upload', tt: 'Йөкләргә', ba: 'Йөкләргә')),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dropdown,
                      const SizedBox(height: 10),
                      uploadButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: dropdown),
                    const SizedBox(width: 12),
                    uploadButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (ctx, index) {
                final cat = categories[index];
                final active = _category == cat;
                return InkWell(
                  onTap: () => setState(() => _category = cat),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? UiTokens.accent : UiTokens.card(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _categoryLabel(cat),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? UiTokens.foreground(context)
                            : UiTokens.muted(context),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: categories.length,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent))
          else if (docs.isEmpty)
            Text(_t('Документы не найдены', 'Документъёс уг шедьты', 'Documents not found', tt: 'Документлар табылмады', ba: 'Документтар табылманы'),
                style: TextStyle(color: UiTokens.muted(context)))
          else
            Column(
              children: List.generate(docs.length, (index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () => _openDocument(doc),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: UiTokens.card(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: UiTokens.cardShadow(context),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: UiTokens.surface(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              doc.isPdf || doc.isDocx
                                  ? Icons.description_outlined
                                  : Icons.image_outlined,
                              size: 18,
                              color: UiTokens.muted(context),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: UiTokens.foreground(context),
                                  ),
                                ),
                                Text(
                                  doc.uploadedAt.isEmpty
                                      ? '—'
                                      : doc.uploadedAt.substring(0, 10),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: UiTokens.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          StatusBadge(
                            label: doc.type,
                            tone: _toneForDoc(doc),
                          ),
                          if (!_isClient)
                            PopupMenuButton<String>(
                              tooltip: _t('Действия', 'Действиеос', 'Actions', tt: 'Гамәлләр', ba: 'Ғәмәлдәр'),
                              onSelected: (value) async {
                                if (value == 'open') {
                                  await _openDocument(doc);
                                  return;
                                }
                                if (value == 'delete') {
                                  final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title:
                                              Text(_t('Удалить документ?', 'Документез быдтыны?', 'Delete document?', tt: 'Документны бетерергәме?', ba: 'Документты юйырғамы?')),
                                          content: Text(doc.name),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: Text(_t('Отмена', 'Бертоны', 'Cancel', tt: 'Кире кагу', ba: 'Кире ҡағыу')),
                                            ),
                                            FilledButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: Text(_t('Удалить', 'Быдтыны', 'Delete', tt: 'Бетерү', ba: 'Юйырға')),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                  if (!confirmed || !mounted) return;
                                  try {
                                    await widget.auth.deleteDocument(doc.id);
                                    await _load();
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e
                                            .toString()
                                            .replaceFirst('Exception: ', '')),
                                      ),
                                    );
                                  }
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'open',
                                  child: Text(_t('Просмотр', 'Учкон', 'Preview', tt: 'Карау', ba: 'Ҡарау')),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(_t('Удалить', 'Быдтыны', 'Delete', tt: 'Бетерү', ba: 'Юйырға')),
                                ),
                              ],
                            ),
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
}
