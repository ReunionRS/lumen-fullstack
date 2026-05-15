import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_language.dart';
import 'core/ui_tokens.dart';
import 'features/auth/app_entry_point.dart';

class LumenGroupApp extends StatefulWidget {
  const LumenGroupApp({super.key});

  @override
  State<LumenGroupApp> createState() => _LumenGroupAppState();
}

class _LumenGroupAppState extends State<LumenGroupApp> {
  static const _languageKey = 'app_language';
  static const _themeModeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.system;
  AppLanguage _language = AppLanguage.ru;
  bool _bootstrapped = false;

  bool get _isDark {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  ThemeMode _themeModeFromRaw(String raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToRaw(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_languageKey) ?? 'ru';
    final rawTheme = prefs.getString(_themeModeKey) ?? 'system';
    if (!mounted) return;
    setState(() {
      _language = AppLanguage.fromCode(raw);
      _themeMode = _themeModeFromRaw(rawTheme);
      _bootstrapped = true;
    });
    AppLanguageStore.set(_language);
  }

  void _toggleTheme() {
    final nextMode = _isDark ? ThemeMode.light : ThemeMode.dark;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_themeModeKey, _themeModeToRaw(nextMode));
    });
    if (!mounted) return;
    setState(() {
      _themeMode = nextMode;
    });
  }

  Future<void> _setLanguage(AppLanguage language) async {
    if (_language == language) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language.code);
    if (!mounted) return;
    setState(() => _language = language);
    AppLanguageStore.set(language);
  }

  static const List<String> _fontFallback = <String>[
    'Noto Sans',
    'sans-serif',
  ];

  TextTheme _withFallback(TextTheme theme) {
    TextStyle? apply(TextStyle? style) =>
        style?.copyWith(fontFamilyFallback: _fontFallback);
    return theme.copyWith(
      displayLarge: apply(theme.displayLarge),
      displayMedium: apply(theme.displayMedium),
      displaySmall: apply(theme.displaySmall),
      headlineLarge: apply(theme.headlineLarge),
      headlineMedium: apply(theme.headlineMedium),
      headlineSmall: apply(theme.headlineSmall),
      titleLarge: apply(theme.titleLarge),
      titleMedium: apply(theme.titleMedium),
      titleSmall: apply(theme.titleSmall),
      bodyLarge: apply(theme.bodyLarge),
      bodyMedium: apply(theme.bodyMedium),
      bodySmall: apply(theme.bodySmall),
      labelLarge: apply(theme.labelLarge),
      labelMedium: apply(theme.labelMedium),
      labelSmall: apply(theme.labelSmall),
    );
  }

  ThemeData _buildLightTheme() {
    const primary = UiTokens.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );
    final baseText = _withFallback(GoogleFonts.dmSansTextTheme());
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(primary: primary, secondary: primary),
      scaffoldBackgroundColor: UiTokens.backgroundLight,
      cardTheme: CardTheme(
        color: UiTokens.cardLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UiTokens.cardLight,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerColor: UiTokens.borderLight,
      textTheme: _withFallback(baseText.copyWith(
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          textStyle: const TextStyle(fontFamilyFallback: _fontFallback),
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          textStyle: const TextStyle(fontFamilyFallback: _fontFallback),
        ),
      )),
    );
  }

  ThemeData _buildDarkTheme() {
    const primary = UiTokens.accent;
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    );
    final baseText = _withFallback(GoogleFonts.dmSansTextTheme(
      ThemeData.dark().textTheme,
    ));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: primary,
        secondary: primary,
        surface: UiTokens.cardDark,
      ),
      scaffoldBackgroundColor: UiTokens.backgroundDark,
      cardTheme: CardTheme(
        color: UiTokens.cardDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: UiTokens.cardDark,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerColor: UiTokens.borderDark,
      textTheme: _withFallback(baseText.copyWith(
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          textStyle: const TextStyle(fontFamilyFallback: _fontFallback),
        ),
        titleMedium: GoogleFonts.spaceGrotesk(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          textStyle: const TextStyle(fontFamilyFallback: _fontFallback),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootstrapped) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: [
          Locale('ru'),
          Locale('en'),
        ],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumen Group',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: _themeMode,
      locale: _language.locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppEntryPoint(
        isDarkMode: _isDark,
        onToggleTheme: _toggleTheme,
        language: _language,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
