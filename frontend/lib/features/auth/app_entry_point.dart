import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../models/session_models.dart';
import '../../services/auth_service.dart';
import '../../services/home_assistant_connection_service.dart';
import '../../services/push_service.dart';
import '../home/home_screen.dart';
import 'home_assistant_onboarding_screen.dart';
import 'login_screen.dart';

class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.language,
    required this.onLanguageChanged,
  });

  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final AppLanguage language;
  final Future<void> Function(AppLanguage language) onLanguageChanged;

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  final _auth = AuthService();
  final _haConnection = HomeAssistantConnectionService();
  bool _loading = true;
  AppSession? _session;
  bool _haConnected = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final session = await _auth.getSession();
    if (session != null) {
      await PushService.instance.registerToken(session);
    }
    final connected =
        session != null ? await _haConnection.isConnected(session.id) : false;
    if (!mounted) return;
    setState(() {
      _session = session;
      _haConnected = connected;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final current = _session;
    if (current != null) {
      await PushService.instance.unregisterToken(current);
      try {
        await _auth.deleteHomeAssistantConnection();
      } catch (_) {}
      await _haConnection.disconnect(current.id);
    }
    await _auth.clearSession();
    if (!mounted) return;
    setState(() {
      _session = null;
      _haConnected = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_loading) {
      child = const SizedBox.expand(
        key: ValueKey('auth_loading_blank'),
      );
    } else if (_session != null) {
      if (!_haConnected) {
        child = HomeAssistantOnboardingScreen(
          key: const ValueKey('ha_onboarding_screen'),
          session: _session!,
          onConnected: () {
            if (!mounted) return;
            setState(() => _haConnected = true);
          },
          onBackToLogin: _logout,
        );
      } else {
        child = HomeScreen(
          key: const ValueKey('home_screen'),
          auth: _auth,
          session: _session!,
          isDarkMode: widget.isDarkMode,
          onToggleTheme: widget.onToggleTheme,
          language: widget.language,
          onLanguageChanged: widget.onLanguageChanged,
          onLogout: _logout,
        );
      }
    } else {
      child = LoginScreen(
        key: const ValueKey('login_screen'),
        auth: _auth,
        onLoginSuccess: (session) async {
          await PushService.instance.registerToken(session);
          final connected = await _haConnection.isConnected(session.id);
          if (!mounted) return;
          setState(() {
            _session = session;
            _haConnected = connected;
          });
        },
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(animation);
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
