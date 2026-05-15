import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/project_models.dart';
import '../../models/session_models.dart';
import '../../models/user_models.dart';
import '../../services/auth_service.dart';
import '../home_v2/document_viewer_page.dart';
import '../home_v2/finances_page.dart';
import '../home_v2/journal_page.dart';
import '../home_v2/maintenance_page.dart';
import '../home_v2/maintenance_requests_page.dart';

class AdminPanelPage extends StatelessWidget {
  const AdminPanelPage({super.key, required this.auth});

  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('Админ панель', 'Админ панель', 'Admin panel')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _AdminTile(
            icon: Icons.group_outlined,
            title: I18n.t('Управление пользователями', 'Пользовательёс управлять', 'User management'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Управление пользователями', 'Пользовательёс управлять', 'User management'),
              child: UsersManagementTab(auth: auth),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.home_work_outlined,
            title: I18n.t('Объекты', 'Объектъёс', 'Projects'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Объекты', 'Объектъёс', 'Projects'),
              child: ProjectsManagementTab(auth: auth),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.folder_open_outlined,
            title: I18n.t('Документы', 'Документъёс', 'Documents'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Документы', 'Документъёс', 'Documents'),
              child: DocumentsManagementTab(auth: auth),
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.calendar_month_outlined,
            title: I18n.t('Плановое обслуживание', 'Планлы обслуживание', 'Scheduled maintenance'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Плановое обслуживание', 'Планлы обслуживание', 'Scheduled maintenance'),
              child: MaintenancePage(
                auth: auth,
                role: 'admin',
                projectId: null,
              ),
              hideAppBar: true,
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.assignment_outlined,
            title: I18n.t('Заявки', 'Заявкаос', 'Requests'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Заявки', 'Заявкаос', 'Requests'),
              child: MaintenanceRequestsPage(auth: auth),
              hideAppBar: true,
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.book_outlined,
            title: I18n.t('Журнал дома', 'Коркалэн журналэз', 'House journal'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Журнал дома', 'Коркалэн журналэз', 'House journal'),
              child: JournalPage(
                auth: auth,
                role: 'admin',
                projectId: null,
              ),
              hideAppBar: true,
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.account_balance_wallet_outlined,
            title: I18n.t('Финансы', 'Финансъёс', 'Finances'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Финансы', 'Финансъёс', 'Finances'),
              child: FinancesPage(
                auth: auth,
                projectId: null,
                role: 'admin',
              ),
              hideAppBar: true,
            ),
          ),
        ],
      ),
    );
  }

  void _openSection(
    BuildContext context, {
    required String title,
    required Widget child,
    bool hideAppBar = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminSectionPage(
          title: title,
          child: child,
          hideAppBar: hideAppBar,
        ),
      ),
    );
  }
}

class _AdminSectionPage extends StatelessWidget {
  const _AdminSectionPage({
    required this.title,
    required this.child,
    required this.hideAppBar,
  });

  final String title;
  final Widget child;
  final bool hideAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hideAppBar ? null : AppBar(title: Text(title)),
      body: child,
    );
  }
}

class _AdminTile extends StatelessWidget {
  const _AdminTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: BorderRadius.circular(18),
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
              child: Icon(icon, color: UiTokens.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.foreground(context),
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: UiTokens.muted(context)),
          ],
        ),
      ),
    );
  }
}

class UsersManagementTab extends StatefulWidget {
  const UsersManagementTab({super.key, required this.auth});

  final AuthService auth;

  @override
  State<UsersManagementTab> createState() => _UsersManagementTabState();
}

class _UsersManagementTabState extends State<UsersManagementTab> {
  bool _loading = true;
  String? _error;
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.auth.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteUser(AppUser user) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить пользователя?'),
            content: Text('Удалить ${user.fio.isEmpty ? user.email : user.fio}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;
    try {
      await widget.auth.deleteUser(user.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editUser(AppUser user) async {
    final fioController = TextEditingController(text: user.fio);
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    String role = user.role;
    bool saving = false;

    final result = await showModalBottomSheet<bool>(
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
                    const Text(
                      'Редактировать пользователя',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                    DropdownButtonFormField<String>(
                      value: role,
                      items: kRoleLabels.entries
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      decoration:
                          const InputDecoration(labelText: 'Новый пароль'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              var sheetClosed = false;
                              setModalState(() => saving = true);
                              try {
                                await widget.auth.updateUser(
                                  userId: user.id,
                                  fio: fioController.text.trim(),
                                  email: emailController.text.trim(),
                                  role: role,
                                  password: passwordController.text,
                                );
                                if (!context.mounted) return;
                                sheetClosed = true;
                                Navigator.of(context).pop(true);
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(e
                                          .toString()
                                          .replaceFirst('Exception: ', ''))),
                                );
                              } finally {
                                if (!sheetClosed && context.mounted) {
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
                          : const Text('Сохранить'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    fioController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (result == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Text('Пользователей пока нет',
            style: TextStyle(color: UiTokens.muted(context))),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _users.length,
        itemBuilder: (context, index) {
          final user = _users[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: UiTokens.surface(context),
                  child: Icon(Icons.person_outline,
                      color: UiTokens.muted(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fio.isEmpty ? user.email : user.fio,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: UiTokens.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: UiTokens.muted(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kRoleLabels[user.role] ?? user.role,
                        style: const TextStyle(
                          color: Color(0xFFED9B00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editUser(user),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Редактировать',
                ),
                IconButton(
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Удалить',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ProjectsManagementTab extends StatefulWidget {
  const ProjectsManagementTab({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ProjectsManagementTab> createState() => _ProjectsManagementTabState();
}

class _ProjectsManagementTabState extends State<ProjectsManagementTab> {
  bool _loading = true;
  String? _error;
  List<ProjectSummary> _projects = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final projects = await widget.auth.fetchProjects();
      if (!mounted) return;
      setState(() => _projects = projects);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProject(ProjectSummary project) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить объект?'),
            content:
                Text('${project.clientFio}\n${project.constructionAddress}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;
    try {
      await widget.auth.deleteProject(project.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_projects.isEmpty) {
      return Center(
        child: Text('Объектов пока нет',
            style: TextStyle(color: UiTokens.muted(context))),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        itemCount: _projects.length,
        itemBuilder: (context, index) {
          final project = _projects[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: UiTokens.surface(context),
                  child: Icon(Icons.home_outlined,
                      color: UiTokens.muted(context)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.constructionAddress,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: UiTokens.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.clientFio,
                        style: TextStyle(color: UiTokens.muted(context)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kProjectStatusLabels[project.status] ?? project.status,
                        style: const TextStyle(
                          color: Color(0xFFED9B00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _deleteProject(project),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Удалить',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class DocumentsManagementTab extends StatefulWidget {
  const DocumentsManagementTab({super.key, required this.auth});

  final AuthService auth;

  @override
  State<DocumentsManagementTab> createState() => _DocumentsManagementTabState();
}

class _DocumentsManagementTabState extends State<DocumentsManagementTab> {
  bool _loading = true;
  String? _error;
  List<ProjectDocument> _docs = const [];
  List<ClientOption> _clients = const [];
  bool _loadingClients = false;
  String? _clientError;
  String? _selectedClientId;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() {
      _loadingClients = true;
      _clientError = null;
    });
    try {
      final clients = await widget.auth.fetchClients();
      if (!mounted) return;
      setState(() => _clients = clients);
    } catch (e) {
      if (!mounted) return;
      setState(() => _clientError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingClients = false);
    }
  }

  Future<void> _loadDocs() async {
    if (_selectedClientId == null || _selectedClientId!.isEmpty) {
      setState(() {
        _docs = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs =
          await widget.auth.fetchDocuments(clientUserId: _selectedClientId);
      if (!mounted) return;
      setState(() => _docs = docs);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDoc(ProjectDocument doc) async {
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

  Future<void> _deleteDoc(ProjectDocument doc) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Удалить документ?'),
            content: Text(doc.name),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;
    try {
      await widget.auth.deleteDocument(doc.id);
      await _loadDocs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDocs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          DropdownButtonFormField<String>(
            value: _selectedClientId,
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Выберите клиента'),
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
                    setState(() => _selectedClientId = value);
                    _loadDocs();
                  },
            decoration: const InputDecoration(labelText: 'Клиент'),
          ),
          if (_loadingClients)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (_clientError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _clientError!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          const SizedBox(height: 16),
          if (_selectedClientId == null)
            Text('Выберите клиента для просмотра документов',
                style: TextStyle(color: UiTokens.muted(context)))
          else if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.redAccent))
          else if (_docs.isEmpty)
            Text('Документы не найдены',
                style: TextStyle(color: UiTokens.muted(context)))
          else
            ..._docs.map(
              (doc) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: UiTokens.card(context),
                  borderRadius: BorderRadius.circular(18),
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
                    IconButton(
                      onPressed: () => _openDoc(doc),
                      icon: const Icon(Icons.open_in_new),
                      tooltip: 'Просмотр',
                    ),
                    IconButton(
                      onPressed: () => _deleteDoc(doc),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Удалить',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
