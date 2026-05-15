import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/i18n.dart';
import '../../core/ui_tokens.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../admin/admin_panel_page.dart';
import 'notifications_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.session,
    required this.auth,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  final AppSession session;
  final AuthService auth;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;
  final Future<void> Function() onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Uint8List? _avatarBytes;
  String _avatarUrl = '';
  bool _pickingAvatar = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.session.avatarUrl;
  }

  Future<void> _pickAvatar() async {
    if (_pickingAvatar) return;
    setState(() => _pickingAvatar = true);
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;
      if (!mounted) return;
      setState(() => _avatarBytes = bytes);
      final avatarUrl = await widget.auth.uploadAvatar(file: file);
      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _pickingAvatar = false);
      }
    }
  }

  void _openSettingsTab(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          initialTab: index,
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

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsPage(
          auth: widget.auth,
          role: widget.session.role,
        ),
      ),
    );
  }

  void _openAdminPanel() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminPanelPage(auth: widget.auth),
      ),
    );
  }

  void _openChangePassword() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(auth: widget.auth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fio = widget.session.fio.isEmpty
        ? I18n.t(
            'Пользователь',
            'Пользователь',
            'User',
            tt: 'Кулланучы',
            ba: 'Ҡулланыусы',
          )
        : widget.session.fio;

    ImageProvider? avatarImage;
    if (_avatarBytes != null) {
      avatarImage = MemoryImage(_avatarBytes!);
    } else if (_avatarUrl.isNotEmpty) {
      avatarImage = NetworkImage(widget.auth.resolveFileUrl(_avatarUrl));
    }

    String roleLabel(String role) {
      switch (role.toLowerCase()) {
        case 'client':
          return I18n.t('Клиент', 'Клиент', 'Client', tt: 'Клиент', ba: 'Клиент');
        case 'admin':
          return I18n.t('Администратор', 'Администратор', 'Administrator', tt: 'Администратор', ba: 'Администратор');
        case 'director':
          return I18n.t('Директор', 'Директор', 'Director', tt: 'Директор', ba: 'Директор');
        case 'manager':
          return I18n.t('Менеджер', 'Менеджер', 'Manager', tt: 'Менеджер', ba: 'Менеджер');
        case 'foreman':
          return I18n.t('Прораб', 'Прораб', 'Foreman', tt: 'Прораб', ba: 'Прораб');
        default:
          return role;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('Профиль', 'Профиль', 'Profile', tt: 'Профиль', ba: 'Профиль')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFFFE8C5),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person_outline,
                            size: 30, color: Color(0xFFED9B00))
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fio,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: UiTokens.foreground(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.session.email,
                        style: TextStyle(color: UiTokens.muted(context)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        roleLabel(widget.session.role),
                        style: const TextStyle(
                          color: Color(0xFFED9B00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_pickingAvatar)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (widget.session.role == 'admin') ...[
            _ProfileTile(
              icon: Icons.admin_panel_settings_outlined,
              title: I18n.t('Админ панель', 'Админ панель', 'Admin panel', tt: 'Админ панеле', ba: 'Админ панеле'),
              onTap: _openAdminPanel,
            ),
            const SizedBox(height: 12),
          ],
          _ProfileTile(
            icon: Icons.lock_outline,
            title: I18n.t('Сменить пароль', 'Пароль вошттыны', 'Change password', tt: 'Серсүзне алыштыру', ba: 'Паролде алмаштырыу'),
            onTap: _openChangePassword,
          ),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.notifications_outlined,
            title: I18n.t('Уведомления', 'Уведомлениеос', 'Notifications', tt: 'Белдерүләр', ba: 'Хәбәрнамәләр'),
            onTap: _openNotifications,
          ),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.shield_outlined,
            title: I18n.t('Безопасность', 'Утинлык', 'Security', tt: 'Иминлек', ba: 'Хәүефһеҙлек'),
            onTap: () => _openSettingsTab(2),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () async {
              await widget.onLogout();
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: UiTokens.card(context),
                borderRadius: BorderRadius.circular(18),
                boxShadow: UiTokens.cardShadow(context),
                border: Border.all(
                  color: UiTokens.border(context),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Color(0xFFED9B00), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    I18n.t('Выйти из аккаунта', 'Аккаунтысь потыны', 'Log out', tt: 'Аккаунттан чыгу', ba: 'Аккаунттан сығыу'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UiTokens.foreground(context),
                    ),
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

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailing;

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
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: UiTokens.muted(context)),
            ),
            const SizedBox(width: 12),
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
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: Color(0xFFED9B00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: UiTokens.muted(context)),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.auth});

  final AuthService auth;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _repeatController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_newController.text.trim().isEmpty ||
        _newController.text != _repeatController.text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('Пароли не совпадают', 'Парольёс уг туртто', 'Passwords do not match', tt: 'Серсүзләр туры килми', ba: 'Паролдәр тап килмәй'))),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.auth.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.t('Пароль изменён', 'Пароль воштэм', 'Password changed', tt: 'Серсүз үзгәртелде', ba: 'Пароль үҙгәртелде'))),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                I18n.t('Сменить пароль', 'Пароль вошттыны', 'Change password', tt: 'Серсүзне алыштыру', ba: 'Паролде алмаштырыу'),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _currentController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: I18n.t('Текущий пароль', 'Анысь пароль', 'Current password', tt: 'Хәзерге серсүз', ba: 'Хәҙерге пароль'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: I18n.t('Новый пароль', 'Выль пароль', 'New password', tt: 'Яңа серсүз', ba: 'Яңы пароль'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _repeatController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: I18n.t('Повторите пароль', 'Парольез кабат', 'Repeat password', tt: 'Серсүзне кабатлагыз', ba: 'Паролде ҡабатлағыҙ'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(I18n.t('Сохранить', 'Утчаны', 'Save', tt: 'Сакларга', ba: 'Һаҡларға')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
