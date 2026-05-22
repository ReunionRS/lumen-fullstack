import 'package:flutter/material.dart';

import '../../models/session_models.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onLoginSuccess,
  });

  final AuthService auth;
  final ValueChanged<AppSession> onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _passwordFieldKey = GlobalKey();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _rememberEmail = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _animateIn = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
    _passwordFocusNode.addListener(_scrollPasswordIntoView);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _animateIn = true);
    });
  }

  Future<void> _loadRememberedEmail() async {
    final email = await widget.auth.getRememberedEmail();
    if (!mounted) return;
    setState(() {
      _emailController.text = email;
      _rememberEmail = email.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.removeListener(_scrollPasswordIntoView);
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _scrollPasswordIntoView() {
    if (!_passwordFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = _passwordFieldKey.currentContext;
      if (!mounted || context == null) return;
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.34,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final session = await widget.auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberEmail: _rememberEmail,
      );
      if (!mounted) return;
      widget.onLoginSuccess(session);
    } on TwoFactorRequiredException catch (twoFactorError) {
      final code = await _askTwoFactorCode();
      if (code == null || code.isEmpty) return;
      final session = await widget.auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberEmail: _rememberEmail,
        twoFactorCode: code,
        twoFactorPendingToken: twoFactorError.pendingToken,
      );
      if (!mounted) return;
      widget.onLoginSuccess(session);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<String?> _askTwoFactorCode() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Код Google Authenticator'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: 'Введите 6-значный код',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor =
        isDark ? const Color(0xFF030A18) : const Color(0xFFF3F4F7);
    final inputColor =
        isDark ? const Color(0xFF111D32) : const Color(0xFFE8EBF0);
    final textDark = isDark ? const Color(0xFFF1F5FF) : const Color(0xFF121826);
    final textMuted =
        isDark ? const Color(0xFF94A3BC) : const Color(0xFF7A8599);
    final actionColor =
        isDark ? const Color(0xFFF1B327) : const Color(0xFF0E1423);
    final actionTextColor = isDark ? const Color(0xFF111827) : Colors.white;

    return Scaffold(
      backgroundColor: panelColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isCompactPhone = width < 380;
          final isDesktop = width >= 900;
          final isTablet = width >= 600 && width < 900;
          final cardMaxWidth = isDesktop
              ? 760.0
              : (isTablet ? 560.0 : (isCompactPhone ? 350.0 : 420.0));
          final heroHeight = isDesktop
              ? 360.0
              : (isTablet ? 300.0 : (isCompactPhone ? 216.0 : 252.0));
          final titleSize = isDesktop
              ? 46.0
              : (isTablet ? 48.0 : (isCompactPhone ? 30.0 : 34.0));
          final subtitleSize =
              isDesktop ? 17.0 : (isCompactPhone ? 14.0 : 15.0);
          final inputFontSize =
              isDesktop ? 16.0 : (isCompactPhone ? 14.0 : 15.0);
          final labelFontSize = isCompactPhone ? 14.0 : 15.0;
          final checkboxFontSize = isCompactPhone ? 15.0 : 17.0;
          final buttonHeight = isCompactPhone ? 56.0 : 60.0;
          final formHorizontalPadding =
              isDesktop ? 28.0 : (isCompactPhone ? 14.0 : 16.0);
          final formTopPadding =
              isDesktop ? 24.0 : (isCompactPhone ? 16.0 : 18.0);
          final formBottomPadding =
              isDesktop ? 24.0 : (isCompactPhone ? 16.0 : 18.0);
          final fieldVerticalPadding = isCompactPhone ? 14.0 : 16.0;

          final heroPanel = AnimatedOpacity(
            opacity: _animateIn ? 1 : 0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              height: heroHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/house-1.jpg', fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? const [Color(0x33000000), Color(0xCC030A18)]
                            : const [Color(0x22000000), Color(0xCCF3F4F7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          final formPanel = Container(
            margin: EdgeInsets.fromLTRB(
              isDesktop ? 0 : (isCompactPhone ? 10 : 14),
              0,
              isDesktop ? 0 : (isCompactPhone ? 10 : 14),
              isDesktop ? 0 : (isCompactPhone ? 12 : 16),
            ),
            padding: EdgeInsets.fromLTRB(
              formHorizontalPadding,
              formTopPadding,
              formHorizontalPadding,
              formBottomPadding,
            ),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(26),
            ),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              offset: _animateIn ? Offset.zero : const Offset(0, 0.08),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutCubic,
                opacity: _animateIn ? 1 : 0,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'С возвращением',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                        ),
                      ),
                      SizedBox(height: isCompactPhone ? 6 : 8),
                      Text(
                        'Войдите, чтобы управлять вашим домом',
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: isCompactPhone ? 14 : 18),
                      Text(
                        'Email',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isCompactPhone ? 8 : 10),
                      TextFormField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: textDark,
                          fontSize: inputFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: textDark,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputColor,
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(
                            color: textMuted,
                            fontSize: inputFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: textMuted,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF4B5A75)
                                  : const Color(0xFFB9C2D3),
                              width: 1.2,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: fieldVerticalPadding,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Введите почту';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: isCompactPhone ? 14 : 18),
                      Text(
                        'Пароль',
                        style: TextStyle(
                          color: textMuted,
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: isCompactPhone ? 8 : 10),
                      TextFormField(
                        key: _passwordFieldKey,
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        onTap: _scrollPasswordIntoView,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          color: textDark,
                          fontSize: inputFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                        cursorColor: textDark,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: inputColor,
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: textMuted,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: textMuted,
                            ),
                          ),
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                            color: textMuted,
                            fontSize: inputFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF4B5A75)
                                  : const Color(0xFFB9C2D3),
                              width: 1.2,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: fieldVerticalPadding,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Введите пароль';
                          return null;
                        },
                      ),
                      SizedBox(height: isCompactPhone ? 10 : 14),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberEmail,
                            activeColor: actionColor,
                            side: BorderSide(color: textMuted),
                            onChanged: (v) =>
                                setState(() => _rememberEmail = v ?? false),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Запомнить',
                            style: TextStyle(
                              color: textMuted,
                              fontSize: checkboxFontSize,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isCompactPhone ? 10 : 12),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: actionTextColor,
                          minimumSize: Size.fromHeight(buttonHeight),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: actionTextColor,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Войти',
                                    style: TextStyle(
                                      fontSize: isCompactPhone ? 18 : 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.arrow_forward_rounded,
                                      size: 24),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

          if (isDesktop) {
            return SizedBox.expand(
              child: Container(
                decoration: BoxDecoration(color: panelColor),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(36, 28, 18, 28),
                        child: Align(
                          alignment: const Alignment(0, 0.22),
                          child: formPanel,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 28, 36, 28),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: SizedBox.expand(child: heroPanel),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          return SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: keyboardInset + 20,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: panelColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heroPanel,
                        formPanel,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
