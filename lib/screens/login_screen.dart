import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/local_auth_service.dart';
import 'menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _minPasswordLength = 6;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _authBusy = false;

  String? _usernameError;
  String? _passwordError;
  String? _confirmError;

  static const double _authButtonHeight = 52;

  static const Duration _captionDuration = Duration(milliseconds: 240);
  static const Duration _captionSwitchDuration = Duration(milliseconds: 200);

  void _clearAllErrors() {
    _usernameError = null;
    _passwordError = null;
    _confirmError = null;
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
    bool hasError = false,
  }) {
    final normal = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    );
    final errorOutline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFE57373), width: 1),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF2E2E2E),
      border: normal,
      enabledBorder: hasError ? errorOutline : normal,
      focusedBorder: hasError ? errorOutline : normal,
      errorBorder: errorOutline,
      focusedErrorBorder: errorOutline,
    );
  }

  /// Подпись под полем: плавная смена высоты и краткий кросс‑фейд текста.
  Widget _animatedFieldCaption({String? error, String? helper}) {
    final display = error ?? helper;
    final isError = error != null;
    return AnimatedSize(
      duration: _captionDuration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: display == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(left: 14, top: 6, right: 8),
              child: AnimatedSwitcher(
                duration: _captionSwitchDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: Align(
                  key: ValueKey<String>('$isError|$display'),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    display,
                    maxLines: 3,
                    style: TextStyle(
                      color: isError
                          ? const Color(0xFFE57373)
                          : Colors.grey,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _applyAsyncError(String error) {
    _clearAllErrors();
    if (error.contains('не найден')) {
      _usernameError = error;
    } else if (error.contains('Неверный пароль')) {
      _passwordError = error;
    } else if (error.contains('зарегистрирован')) {
      _usernameError = error;
    } else {
      _passwordError = error;
    }
  }

  Future<void> _authenticate() async {
    if (_authBusy) return;

    setState(() {
      _clearAllErrors();
    });

    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _usernameError = 'Введите логин');
      return;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Введите пароль');
      return;
    }

    if (!_isLogin) {
      if (_passwordController.text.length < _minPasswordLength) {
        setState(
          () => _passwordError = 'Пароль не короче $_minPasswordLength символов',
        );
        return;
      }
      if (_confirmPasswordController.text.isEmpty) {
        setState(() => _confirmError = 'Подтвердите пароль');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() => _confirmError = 'Пароли не совпадают');
        return;
      }
    }

    setState(() => _authBusy = true);
    String? error;
    try {
      if (_isLogin) {
        error = await LocalAuthService.login(username, _passwordController.text);
      } else {
        error = await LocalAuthService.register(username, _passwordController.text);
      }
    } finally {
      if (mounted) setState(() => _authBusy = false);
    }

    if (!mounted) return;

    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _applyAsyncError(error!));
      });
      return;
    }

    Provider.of<GameProvider>(context, listen: false).setProfileName(username);

    Navigator.of(context).pushReplacement(
      buildAppRoute(const MenuScreen()),
    );
  }

  Widget _buildAuthFieldsAnimated() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _usernameController,
          onChanged: (_) {
            if (_usernameError != null) setState(() => _usernameError = null);
          },
          style: const TextStyle(color: Colors.white),
          decoration: _decoration(
            hint: 'Логин',
            icon: Icons.person,
            hasError: _usernameError != null,
          ),
        ),
        _animatedFieldCaption(error: _usernameError, helper: null),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          onChanged: (_) {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
          style: const TextStyle(color: Colors.white),
          decoration: _decoration(
            hint: 'Пароль',
            icon: Icons.lock,
            hasError: _passwordError != null,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),
        _animatedFieldCaption(
          error: _passwordError,
          helper: !_isLogin && _passwordError == null
              ? 'Не короче $_minPasswordLength символов'
              : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _isLogin
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      onChanged: (_) {
                        if (_confirmError != null) {
                          setState(() => _confirmError = null);
                        }
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        hint: 'Подтвердить пароль',
                        icon: Icons.lock,
                        hasError: _confirmError != null,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword = !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    _animatedFieldCaption(
                      error: _confirmError,
                      helper: _confirmError == null
                          ? 'Такой же, как в поле «Пароль»'
                          : null,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: _authButtonHeight,
          child: ElevatedButton(
            onPressed: () => _authenticate(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF404040),
              disabledBackgroundColor: const Color(0xFF404040),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _authBusy
                ? const SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white70,
                    ),
                  )
                : Text(
                    _isLogin ? 'Войти' : 'Зарегистрироваться',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1C1C1C), Color(0xFF0B0B0B)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/ico.png',
                      width: 92,
                      height: 92,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Шахматы',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1C),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2E2E2E),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = true;
                                      _clearAllErrors();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isLogin
                                        ? const Color(0xFF404040)
                                        : const Color(0xFF2E2E2E),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Вход',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLogin = false;
                                      _usernameController.clear();
                                      _passwordController.clear();
                                      _confirmPasswordController.clear();
                                      _clearAllErrors();
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !_isLogin
                                        ? const Color(0xFF404040)
                                        : const Color(0xFF2E2E2E),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Регистрация',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _buildAuthFieldsAnimated(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
