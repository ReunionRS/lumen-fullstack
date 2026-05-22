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
import '../home_v2/support_chat_page.dart';

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
            title: I18n.t('Управление пользователями',
                'Пользовательёс управлять', 'User management'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Управление пользователями',
                  'Пользовательёс управлять', 'User management'),
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
            title: I18n.t('Плановое обслуживание', 'Планлы обслуживание',
                'Scheduled maintenance'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Плановое обслуживание', 'Планлы обслуживание',
                  'Scheduled maintenance'),
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
            icon: Icons.support_agent,
            title: I18n.t('Поддержка', 'Поддержка', 'Support',
                tt: 'Ярдәм', ba: 'Ярҙәм'),
            onTap: () => _openSection(
              context,
              title: I18n.t('Поддержка', 'Поддержка', 'Support',
                  tt: 'Ярдәм', ba: 'Ярҙәм'),
              child: SupportPage(
                auth: auth,
                role: 'admin',
              ),
              hideAppBar: true,
            ),
          ),
          const SizedBox(height: 12),
          _AdminTile(
            icon: Icons.book_outlined,
            title: I18n.t('Журнал дома', 'Коркалэн журналэз', 'House journal'),
            onTap: () => _openSection(
              context,
              title:
                  I18n.t('Журнал дома', 'Коркалэн журналэз', 'House journal'),
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
          hideAppBar: hideAppBar,
          child: child,
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
  final _userSearchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<AppUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    super.dispose();
  }

  List<AppUser> get _filteredUsers {
    final query = _userSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _users;
    return _users.where((user) {
      return user.fio.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          (kRoleLabels[user.role] ?? user.role).toLowerCase().contains(query);
    }).toList(growable: false);
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
            content:
                Text('Удалить ${user.fio.isEmpty ? user.email : user.fio}?'),
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

  Future<void> _createUser() async {
    final fioController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String role = 'client';
    var sendWelcomeEmail = true;
    var saving = false;

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
                  color: UiTokens.card(context),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Добавить пользователя',
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
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Пароль'),
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: sendWelcomeEmail,
                          onChanged: (value) => setModalState(
                              () => sendWelcomeEmail = value ?? true),
                          title: const Text('Отправить письмо с доступом'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  final fio = fioController.text.trim();
                                  final email = emailController.text.trim();
                                  final password = passwordController.text;
                                  if (fio.isEmpty ||
                                      email.isEmpty ||
                                      password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Заполните ФИО, email и пароль'),
                                      ),
                                    );
                                    return;
                                  }
                                  var sheetClosed = false;
                                  setModalState(() => saving = true);
                                  try {
                                    await widget.auth.createUser(
                                      fio: fio,
                                      email: email,
                                      password: password,
                                      role: role,
                                      sendWelcomeEmail: sendWelcomeEmail,
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
                                            .replaceFirst('Exception: ', '')),
                                      ),
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
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Добавить'),
                        ),
                      ],
                    ),
                  ),
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
                  color: UiTokens.card(context),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Редактировать пользователя',
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
                        obscureText: true,
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
                                          .replaceFirst('Exception: ', '')),
                                    ),
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

    fioController.dispose();
    emailController.dispose();
    passwordController.dispose();

    if (result == true) {
      await _load();
    }
  }

  Future<void> _toggleUserStatus(AppUser user, bool isActive) async {
    try {
      await widget.auth.updateUserState(
        user.id,
        isActive: isActive,
        isArchived: false,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openUserActions(AppUser user) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final active = user.isActive && !user.isArchived;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: UiTokens.card(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _UserAvatar(user: user, auth: widget.auth, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fio.isEmpty ? user.email : user.fio,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: UiTokens.foreground(ctx),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: UiTokens.muted(ctx)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  title: const Text('Аккаунт активен'),
                  subtitle: Text(active ? 'Активен' : 'Неактивен'),
                  activeColor: UiTokens.success,
                  onChanged: (value) async {
                    Navigator.of(ctx).pop(value ? 'activate' : 'deactivate');
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: UiTokens.accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop('edit');
                        },
                        child: const Text('Редактировать'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(ctx).pop('delete');
                        },
                        child: const Text('Удалить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'activate':
        await _toggleUserStatus(user, true);
        break;
      case 'deactivate':
        await _toggleUserStatus(user, false);
        break;
      case 'edit':
        await _editUser(user);
        break;
      case 'delete':
        await _deleteUser(user);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
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
        child: Text(
          'Пользователей пока нет',
          style: TextStyle(color: UiTokens.muted(context)),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
            children: [
              TextField(
                controller: _userSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: UiTokens.card(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: UiTokens.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: UiTokens.accent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Center(
                    child: Text(
                      'Пользователи не найдены',
                      style: TextStyle(color: UiTokens.muted(context)),
                    ),
                  ),
                )
              else
                ...users.map((user) {
                  final active = user.isActive && !user.isArchived;
                  return InkWell(
                    onTap: () => _openUserActions(user),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: UiTokens.card(context),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: UiTokens.cardShadow(context),
                      ),
                      child: Row(
                        children: [
                          _UserAvatar(user: user, auth: widget.auth),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fio.isEmpty ? user.email : user.fio,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: UiTokens.foreground(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      TextStyle(color: UiTokens.muted(context)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  kRoleLabels[user.role] ?? user.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFED9B00),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            active ? 'Активен' : 'Неактивен',
                            style: TextStyle(
                              color:
                                  active ? UiTokens.success : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: UiTokens.muted(context)),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _createUser,
            backgroundColor: UiTokens.accent,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.user,
    required this.auth,
    this.radius = 22,
  });

  final AppUser user;
  final AuthService auth;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        user.avatarUrl.isEmpty ? '' : auth.resolveFileUrl(user.avatarUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: UiTokens.surface(context),
      backgroundImage: avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
      child: avatarUrl.isEmpty
          ? Icon(Icons.person_outline, color: UiTokens.muted(context))
          : null,
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
  final _searchController = TextEditingController();
  bool _loading = true;
  String? _error;
  List<ProjectSummary> _projects = const [];
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isConstructionProject(ProjectSummary project) {
    final status = project.status.toLowerCase();
    return status.contains('construction') ||
        status.contains('draft') ||
        status.contains('in_progress') ||
        project.progress < 100;
  }

  List<ProjectSummary> get _filteredProjects {
    final query = _searchController.text.trim().toLowerCase();
    return _projects.where((project) {
      if (_filter == 'construction' && !_isConstructionProject(project)) {
        return false;
      }
      if (_filter == 'operation' && _isConstructionProject(project)) {
        return false;
      }
      if (query.isEmpty) return true;
      return project.constructionAddress.toLowerCase().contains(query) ||
          project.clientFio.toLowerCase().contains(query);
    }).toList(growable: false);
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
    final constructionCount = _projects.where(_isConstructionProject).length;
    final operationCount = _projects.length - constructionCount;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: UiTokens.foreground(context)),
                  decoration: InputDecoration(
                    hintText: 'Поиск объектов',
                    hintStyle: TextStyle(color: UiTokens.muted(context)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: UiTokens.muted(context),
                    ),
                    filled: true,
                    fillColor: UiTokens.card(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: UiTokens.border(context)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: UiTokens.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: UiTokens.card(context),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: UiTokens.border(context)),
                ),
                child: Icon(
                  Icons.filter_alt_outlined,
                  color: UiTokens.foreground(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ProjectFilterChip(
                  label: 'Все',
                  count: _projects.length,
                  selected: _filter == 'all',
                  onTap: () => setState(() => _filter = 'all'),
                ),
                _ProjectFilterChip(
                  label: 'Строительство',
                  count: constructionCount,
                  selected: _filter == 'construction',
                  onTap: () => setState(() => _filter = 'construction'),
                ),
                _ProjectFilterChip(
                  label: 'Эксплуатация',
                  count: operationCount,
                  selected: _filter == 'operation',
                  onTap: () => setState(() => _filter = 'operation'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          else if (_filteredProjects.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Text(
                  'Объекты не найдены',
                  style: TextStyle(color: UiTokens.muted(context)),
                ),
              ),
            )
          else
            ..._filteredProjects.map(
              (project) => _ProjectDesignCard(
                project: project,
                auth: widget.auth,
                isConstruction: _isConstructionProject(project),
                onLongPress: () => _deleteProject(project),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProjectFilterChip extends StatelessWidget {
  const _ProjectFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? UiTokens.accent : UiTokens.border(context),
            ),
          ),
          child: Text(
            '$label  $count',
            style: TextStyle(
              color: selected ? UiTokens.accent : UiTokens.foreground(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectDesignCard extends StatelessWidget {
  const _ProjectDesignCard({
    required this.project,
    required this.auth,
    required this.isConstruction,
    required this.onLongPress,
  });

  final ProjectSummary project;
  final AuthService auth;
  final bool isConstruction;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final statusText = _statusText(project);
    final statusColor = _statusColor(project);
    final thumbnailUrl = project.thumbnailUrl.isEmpty
        ? ''
        : auth.resolveFileUrl(project.thumbnailUrl);

    return InkWell(
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: UiTokens.border(context)),
          boxShadow: UiTokens.cardShadow(context),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                height: 88,
                child: thumbnailUrl.isEmpty
                    ? const _ProjectImageFallback()
                    : Image.network(
                        thumbnailUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const _ProjectImageFallback(),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 86,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.constructionAddress.isEmpty
                          ? 'Объект'
                          : project.constructionAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: UiTokens.foreground(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isConstruction ? 'Строительство' : 'Эксплуатация',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: UiTokens.muted(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      project.clientFio.isEmpty ? 'этажей' : project.clientFio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: UiTokens.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 116,
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(ProjectSummary project) {
    if (project.progress >= 100 || project.status == 'completed') {
      return 'Завершен';
    }
    if (project.progress <= 0 || project.status == 'draft') {
      return 'Ожидает старта';
    }
    return 'В работе';
  }

  Color _statusColor(ProjectSummary project) {
    if (project.progress <= 0 || project.status == 'draft') {
      return const Color(0xFFFFB800);
    }
    return const Color(0xFF2BFF73);
  }
}

class _ProjectImageFallback extends StatelessWidget {
  const _ProjectImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UiTokens.surface(context),
      child: Icon(
        Icons.apartment,
        color: UiTokens.muted(context),
        size: 34,
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
      setState(
          () => _clientError = e.toString().replaceFirst('Exception: ', ''));
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
      final url = doc.isDocx
          ? await widget.auth.documentPreviewHtmlUrl(doc.id)
          : await widget.auth.documentViewUrl(doc.id, inline: true);
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
