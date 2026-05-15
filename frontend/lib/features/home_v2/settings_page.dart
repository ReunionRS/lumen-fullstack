import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_language.dart';
import '../../core/ui_tokens.dart';
import '../../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialTab = 0,
    required this.auth,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChanged,
    required this.onLogout,
  });

  final int initialTab;
  final AuthService auth;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;
  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _languageKey = 'app_language';
  late AppLanguage _language;
  bool _initialHandled = false;
  bool _loadingLanguage = true;

  @override
  void initState() {
    super.initState();
    _language = widget.language;
    _loadLanguageFromStorage();
    _openInitialIfNeeded();
  }

  Future<void> _loadLanguageFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_languageKey);
    if (!mounted) return;
    setState(() {
      if (raw != null && raw.isNotEmpty) {
        _language = AppLanguage.fromCode(raw);
      }
      _loadingLanguage = false;
    });
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _language = widget.language;
    }
  }

  void _openInitialIfNeeded() {
    if (_initialHandled || widget.initialTab <= 0) return;
    _initialHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = widget.initialTab.clamp(0, 2);
      if (index == 1) {
        _openLanguage();
      } else if (index == 2) {
        _openSecurity();
      }
    });
  }

  void _openAppearance() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AppearancePage(
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          language: widget.language,
        ),
      ),
    );
  }

  void _openLanguage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LanguagePage(
          language: _language,
          onChanged: (value) async {
            setState(() => _language = value);
            await widget.onLanguageChanged(value);
          },
        ),
      ),
    );
  }

  void _openSecurity() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SecurityPage(
          auth: widget.auth,
          twoFactor: false,
          language: widget.language,
          onChanged: (_) {},
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String t(
      String ru,
      String udm,
      String en, {
      String? tt,
      String? ba,
    }) {
      switch (_language) {
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

    if (_loadingLanguage) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('Настройки', 'Кельтэтъёс', 'Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: t('Внешний вид', 'Тышкы тус', 'Appearance', tt: 'Күренеш', ba: 'Тышҡы ҡиәфәт'),
            subtitle: widget.isDarkMode
                ? t('Тёмная тема', 'Пеймыт тема', 'Dark theme', tt: 'Кара тема', ba: 'Ҡара тема')
                : t('Светлая тема', 'Югыт тема', 'Light theme', tt: 'Якты тема', ba: 'Яҡты тема'),
            onTap: _openAppearance,
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: t('Язык', 'Кыл', 'Language', tt: 'Тел', ba: 'Тел'),
            subtitle: _language.ruLabel,
            onTap: _openLanguage,
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: t('Безопасность', 'Утинлык', 'Security', tt: 'Иминлек', ba: 'Хәүефһеҙлек'),
            subtitle: t('Защита и доступ', 'Утён но пырон', 'Protection and access', tt: 'Саклау һәм керү', ba: 'Һаҡлау һәм инеү'),
            onTap: _openSecurity,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: UiTokens.surface(context),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: UiTokens.muted(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: UiTokens.muted(context),
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
}

class _AppearancePage extends StatelessWidget {
  const _AppearancePage({
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.language,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    String t(
      String ru,
      String udm,
      String en, {
      String? tt,
      String? ba,
    }) {
      switch (language) {
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

    return Scaffold(
      appBar: AppBar(title: Text(t('Внешний вид', 'Тышкы тус', 'Appearance', tt: 'Күренеш', ba: 'Тышҡы ҡиәфәт'))),
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
            child: SwitchListTile.adaptive(
              value: isDarkMode,
              onChanged: (_) => onToggleTheme(),
              title: Text(t('Тёмная тема', 'Пеймыт тема', 'Dark theme', tt: 'Кара тема', ba: 'Ҡара тема')),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePage extends StatefulWidget {
  const _LanguagePage({
    required this.language,
    required this.onChanged,
  });

  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onChanged;

  @override
  State<_LanguagePage> createState() => _LanguagePageState();
}

class _LanguagePageState extends State<_LanguagePage> {
  late AppLanguage _selected;

  TextStyle _langStyle(BuildContext context) {
    return GoogleFonts.notoSans(
      textStyle: TextStyle(
        fontSize: 15,
        color: UiTokens.foreground(context),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.language;
  }

  @override
  void didUpdateWidget(covariant _LanguagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language != widget.language) {
      _selected = widget.language;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected == AppLanguage.udm
              ? 'Кыл'
              : _selected == AppLanguage.tt
                  ? 'Тел'
                  : _selected == AppLanguage.ba
                      ? 'Тел'
              : _selected == AppLanguage.en
                  ? 'Language'
                  : 'Язык',
        ),
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
            child: Column(
              children: [
                RadioListTile<String>(
                  value: AppLanguage.ru.code,
                  groupValue: _selected.code,
                  onChanged: (value) async {
                    if (value == null) return;
                    final next = AppLanguage.fromCode(value);
                    setState(() => _selected = next);
                    await widget.onChanged(next);
                  },
                  title: Text('Русский', style: _langStyle(context)),
                ),
                RadioListTile<String>(
                  value: AppLanguage.udm.code,
                  groupValue: _selected.code,
                  onChanged: (value) async {
                    if (value == null) return;
                    final next = AppLanguage.fromCode(value);
                    setState(() => _selected = next);
                    await widget.onChanged(next);
                  },
                  title: Text('Удмурт кыл', style: _langStyle(context)),
                ),
                RadioListTile<String>(
                  value: AppLanguage.en.code,
                  groupValue: _selected.code,
                  onChanged: (value) async {
                    if (value == null) return;
                    final next = AppLanguage.fromCode(value);
                    setState(() => _selected = next);
                    await widget.onChanged(next);
                  },
                  title: Text('English', style: _langStyle(context)),
                ),
                RadioListTile<String>(
                  value: AppLanguage.tt.code,
                  groupValue: _selected.code,
                  onChanged: (value) async {
                    if (value == null) return;
                    final next = AppLanguage.fromCode(value);
                    setState(() => _selected = next);
                    await widget.onChanged(next);
                  },
                  title: Text('Татарча', style: _langStyle(context)),
                ),
                RadioListTile<String>(
                  value: AppLanguage.ba.code,
                  groupValue: _selected.code,
                  onChanged: (value) async {
                    if (value == null) return;
                    final next = AppLanguage.fromCode(value);
                    setState(() => _selected = next);
                    await widget.onChanged(next);
                  },
                  title: Text('Башҡортса', style: _langStyle(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityPage extends StatefulWidget {
  const _SecurityPage({
    required this.auth,
    required this.twoFactor,
    required this.language,
    required this.onChanged,
    required this.onLogout,
  });

  final AuthService auth;
  final bool twoFactor;
  final AppLanguage language;
  final void Function(bool twoFactor) onChanged;
  final Future<void> Function() onLogout;

  @override
  State<_SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<_SecurityPage> {
  bool _twoFactor = false;
  bool _loading = true;
  bool _processing = false;
  bool _disableMode = false;
  String _setupSecret = '';
  String _setupOtpUri = '';
  final TextEditingController _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _twoFactor = widget.twoFactor;
    _loadStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final enabled = await widget.auth.getTwoFactorStatus();
      if (!mounted) return;
      setState(() {
        _twoFactor = enabled;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _startEnableTwoFactor() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final setup = await widget.auth.setupTwoFactor();
      if (!mounted) return;
      setState(() {
        _setupSecret = (setup['secret'] ?? '').trim();
        _setupOtpUri = (setup['otpauthUrl'] ?? '').trim();
        _disableMode = false;
        _codeController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _twoFactor = false);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmEnableTwoFactor() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите 6-значный код')),
      );
      return;
    }
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await widget.auth.enableTwoFactor(code: code);
      if (!mounted) return;
      setState(() {
        _twoFactor = true;
        _setupSecret = '';
        _setupOtpUri = '';
        _disableMode = false;
        _codeController.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('2FA включена')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmDisableTwoFactor() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите 6-значный код')),
      );
      return;
    }
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await widget.auth.disableTwoFactor(code: code);
      if (!mounted) return;
      setState(() {
        _twoFactor = false;
        _setupSecret = '';
        _setupOtpUri = '';
        _disableMode = false;
        _codeController.clear();
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('2FA отключена')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      if (mounted) setState(() => _twoFactor = true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String t(
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

    return Scaffold(
      appBar: AppBar(title: Text(t('Безопасность', 'Утинлык', 'Security', tt: 'Иминлек', ba: 'Хәүефһеҙлек'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _twoFactor,
                  onChanged: (value) {
                    if (value) {
                      _startEnableTwoFactor();
                    } else {
                      setState(() {
                        _disableMode = true;
                        _setupSecret = '';
                        _setupOtpUri = '';
                        _codeController.clear();
                      });
                    }
                  },
                  title:
                      Text(t('Двухфакторная защита', '2-факторлы утён', 'Two-factor protection', tt: 'Ике факторлы саклау', ba: 'Ике факторлы һаҡлау')),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_setupSecret.isNotEmpty || _disableMode) ...[
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  if (_setupSecret.isNotEmpty) ...[
                    if (_setupOtpUri.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _setupOtpUri,
                            size: 180,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SelectableText(
                      'Резервный ключ: $_setupSecret',
                      style: TextStyle(color: UiTokens.foreground(context)),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    Text(
                      'Подтвердите отключение 2FA кодом из Google Authenticator.',
                      style: TextStyle(color: UiTokens.muted(context)),
                    ),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Код подтверждения',
                      hintText: '000000',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _processing
                              ? null
                              : () => setState(() {
                                  _twoFactor = _disableMode ? true : false;
                                  _setupSecret = '';
                                  _setupOtpUri = '';
                                  _disableMode = false;
                                  _codeController.clear();
                                }),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _processing
                              ? null
                              : (_disableMode
                                  ? _confirmDisableTwoFactor
                                  : _confirmEnableTwoFactor),
                          child: Text(_disableMode ? 'Отключить' : 'Включить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              await widget.onLogout();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(t('Выйти из аккаунта', 'Аккаунтысь потыны', 'Log out', tt: 'Аккаунттан чыгу', ba: 'Аккаунттан сығыу')),
          ),
        ],
      ),
    );
  }
}
