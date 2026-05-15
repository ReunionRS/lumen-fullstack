import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/home_assistant_connection.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../../services/home_assistant_auth_service.dart';
import '../../services/home_assistant_connection_service.dart';
import '../../services/home_assistant_discovery_service.dart';

class HomeAssistantOnboardingScreen extends StatefulWidget {
  const HomeAssistantOnboardingScreen({
    super.key,
    required this.session,
    required this.onConnected,
    required this.onBackToLogin,
  });

  final AppSession session;
  final VoidCallback onConnected;
  final VoidCallback onBackToLogin;

  @override
  State<HomeAssistantOnboardingScreen> createState() =>
      _HomeAssistantOnboardingScreenState();
}

class _HomeAssistantOnboardingScreenState
    extends State<HomeAssistantOnboardingScreen> {
  final _discovery = HomeAssistantDiscoveryService();
  final _auth = HomeAssistantAuthService();
  final _appAuth = AuthService();
  final _connectionService = HomeAssistantConnectionService();

  bool _searching = false;
  bool _connecting = false;
  List<HomeAssistantInstance> _instances = const [];
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    _restorePendingWebOAuth();
  }

  Future<void> _restorePendingWebOAuth() async {
    if (!kIsWeb) return;
    final pendingBaseUrl = await _auth.getPendingBaseUrl();
    if (!mounted) return;
    if (pendingBaseUrl != null && pendingBaseUrl.isNotEmpty) {
      setState(() => _selectedUrl = pendingBaseUrl);
    }
    if (Uri.base.path == '/ha-oauth-web-callback' &&
        Uri.base.queryParameters['code'] != null) {
      await _connect();
    }
  }

  Future<void> _findInstances() async {
    setState(() {
      _searching = true;
      _instances = const [];
      _selectedUrl = null;
    });
    try {
      final items = await _discovery.discoverInstances();
      if (!mounted) return;
      setState(() {
        _instances = items;
        if (items.isNotEmpty) {
          _selectedUrl = items.first.baseUrl;
        }
      });
      if (items.isEmpty) {
        _showMessage(
          'Не удалось найти Home Assistant. Убедитесь, что телефон и Home Assistant подключены к одной Wi-Fi сети.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Не удалось найти Home Assistant. Убедитесь, что телефон и Home Assistant подключены к одной Wi-Fi сети.',
      );
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _enterManualAddress() async {
    final controller = TextEditingController(text: _selectedUrl ?? 'http://');
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Указать адрес вручную'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.10:8123',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7A00),
              ),
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (value == null || value.isEmpty) return;
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
            ? value
            : 'http://$value';

    setState(() {
      _selectedUrl = normalized;
      if (_instances.every((item) => item.baseUrl != normalized)) {
        _instances = [
          HomeAssistantInstance(
            name: 'Вручную',
            host: normalized,
            port: 8123,
            baseUrl: normalized,
          ),
          ..._instances,
        ];
      }
    });
  }

  Future<void> _connect() async {
    final baseUrl = _selectedUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      _showMessage('Сначала выберите Home Assistant');
      return;
    }

    setState(() => _connecting = true);
    try {
      final (code, _) = await _auth.handleCallback(baseUrl: baseUrl);
      final token =
          await _auth.exchangeCodeForToken(baseUrl: baseUrl, code: code);

      final connection = HomeAssistantConnection(
        id: '${widget.session.id}_${DateTime.now().millisecondsSinceEpoch}',
        userId: widget.session.id,
        houseId: '',
        baseUrl: baseUrl,
        accessToken: token.accessToken,
        refreshToken: token.refreshToken,
        expiresAt: DateTime.now().add(Duration(seconds: token.expiresIn)),
        status: 'connected',
        lastCheckedAt: DateTime.now(),
      );
      await _connectionService.saveConnection(connection);
      await _appAuth.saveHomeAssistantConnection(
        baseUrl: connection.baseUrl,
        accessToken: connection.accessToken,
        refreshToken: connection.refreshToken,
        expiresAt: connection.expiresAt,
        houseId: connection.houseId,
        clientId: _auth.clientId,
      );
      await _auth.clearPendingBaseUrl();
      if (!mounted) return;

      _showMessage('Home Assistant успешно подключён');
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (!mounted) return;
      widget.onConnected();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst('Exception: ', '');
      final message = raw.toLowerCase();
      if (message.contains('canceled') || message.contains('cancel')) {
        _showMessage('Подключение отменено');
      } else if (message.contains('oauth_redirect_started')) {
        return;
      } else if (message.contains('invalid redirect uri')) {
        _showMessage(
          'Ошибка OAuth: для client_id не настроен redirect_uri. Откройте настройки интеграции.',
        );
      } else if (message.contains('client_id использует localhost')) {
        _showMessage(raw);
      } else {
        _showMessage('Не удалось завершить подключение Home Assistant: $raw');
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const accent = Color(0xFFFF7A00);
    final bg = isDark ? const Color(0xFF070B14) : const Color(0xFFF5F6F8);
    final textPrimary =
        isDark ? const Color(0xFFF2F5FA) : const Color(0xFF111827);
    final textSecondary =
        isDark ? const Color(0xFF9AA7BC) : const Color(0xFF667085);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final iconBg = isDark ? const Color(0xFF1D2A3D) : const Color(0xFFFFF3E8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: widget.onBackToLogin,
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isSmall = width < 380;
            final contentWidth = math.min(width, 760.0);
            final horizontal = isSmall ? 16.0 : 20.0;
            final sectionGap = isSmall ? 18.0 : 24.0;
            final titleSize = width.clamp(320.0, 760.0) < 400 ? 30.0 : 34.0;
            final descriptionSize = isSmall ? 15.0 : 16.0;
            final sectionTitleSize = isSmall ? 20.0 : 22.0;
            final illustrationHeight = isSmall
                ? 150.0
                : (width < 480 ? 170.0 : (width < 700 ? 200.0 : 230.0));

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 4, horizontal, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Давайте найдём ваш Home Assistant',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Мы поможем подключить ваш Home Assistant, чтобы управлять домом в одном приложении.',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: descriptionSize,
                          height: 1.32,
                        ),
                      ),
                      SizedBox(height: isSmall ? 16 : 20),
                      Container(
                        width: double.infinity,
                        height: illustrationHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: cardBg,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.24 : 0.06),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(isSmall ? 12 : 16),
                        child: Image.asset(
                          isDark
                              ? 'assets/images/home_assistant_connection_dark.png'
                              : 'assets/images/home_assistant_connection_light.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      _Section(
                        title: 'Автоматический поиск в сети',
                        titleSize: sectionTitleSize,
                        textColor: textPrimary,
                        child: _ActionCard(
                          icon: Icons.travel_explore_rounded,
                          title: 'Найти Home Assistant',
                          subtitle: _searching
                              ? 'Мы ищем Home Assistant в вашей локальной сети...'
                              : 'Поиск в локальной сети',
                          actionLabel: _searching ? 'Поиск...' : 'Найти',
                          onTap: _searching ? null : _findInstances,
                          cardColor: cardBg,
                          iconBgColor: iconBg,
                          textColor: textPrimary,
                          mutedTextColor: textSecondary,
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      _Section(
                        title: 'Ручное подключение',
                        titleSize: sectionTitleSize,
                        textColor: textPrimary,
                        child: _ActionCard(
                          icon: Icons.public_rounded,
                          title: 'Указать адрес вручную',
                          subtitle: _selectedUrl == null
                              ? 'Введите адрес вашего Home Assistant'
                              : 'Текущий адрес: $_selectedUrl',
                          actionLabel: 'Указать',
                          onTap: _enterManualAddress,
                          cardColor: cardBg,
                          iconBgColor: iconBg,
                          textColor: textPrimary,
                          mutedTextColor: textSecondary,
                        ),
                      ),
                      if (_instances.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: _instances
                                .map(
                                  (item) => RadioListTile<String>(
                                    value: item.baseUrl,
                                    groupValue: _selectedUrl,
                                    activeColor: accent,
                                    title: Text(
                                      item.name.isEmpty ? item.host : item.name,
                                      style: TextStyle(color: textPrimary),
                                    ),
                                    subtitle: Text(
                                      item.baseUrl,
                                      style: TextStyle(color: textSecondary),
                                    ),
                                    onChanged: _connecting
                                        ? null
                                        : (value) {
                                            if (value == null) return;
                                            setState(
                                                () => _selectedUrl = value);
                                          },
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ],
                      SizedBox(height: sectionGap),
                      _Section(
                        title: 'Что вам понадобится',
                        titleSize: sectionTitleSize,
                        textColor: textPrimary,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _NeedItem(
                                text:
                                    '1. Home Assistant должен быть запущен в вашей локальной сети',
                                color: textSecondary,
                              ),
                              const SizedBox(height: 10),
                              _NeedItem(
                                text:
                                    '2. У вас должны быть права администратора в Home Assistant',
                                color: textSecondary,
                              ),
                              const SizedBox(height: 10),
                              _NeedItem(
                                text: '3. Мы не храним ваши пароли',
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: sectionGap),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF201A12)
                              : const Color(0xFFFFF5EA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Не получается найти?',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Убедитесь, что телефон и Home Assistant подключены к одной Wi-Fi сети.',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 14,
                                height: 1.28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _connecting ? null : _connect,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _connecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Подключить',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    required this.titleSize,
    required this.textColor,
  });

  final String title;
  final Widget child;
  final double titleSize;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
    required this.cardColor,
    required this.iconBgColor,
    required this.textColor,
    required this.mutedTextColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onTap;
  final Color cardColor;
  final Color iconBgColor;
  final Color textColor;
  final Color mutedTextColor;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFFF7A00);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: mutedTextColor,
                              fontSize: 14,
                              height: 1.26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(actionLabel),
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: mutedTextColor,
                        fontSize: 14,
                        height: 1.26,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: Text(actionLabel),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NeedItem extends StatelessWidget {
  const _NeedItem({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 14,
        height: 1.3,
      ),
    );
  }
}
