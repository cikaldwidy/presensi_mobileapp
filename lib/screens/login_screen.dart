import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
    required this.onNeedsFaceRegistration,
  });

  final AuthService authService;
  final VoidCallback onLoggedIn;
  final VoidCallback onNeedsFaceRegistration;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      _showMessage('Username/email/NIP dan password wajib diisi.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await widget.authService.login(
        login: login,
        password: password,
      );
      if (!mounted) return;
      if (user.hasFaceEnrollment) {
        widget.onLoggedIn();
      } else {
        widget.onNeedsFaceRegistration();
      }
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage(
        'Tidak bisa terhubung ke server. baseUrl aktif: ${ApiConfig.baseUrl}',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openFaceRegistration() async {
    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      _showMessage('Isi NIP/username dan password untuk pendaftaran wajah.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.authService.login(login: login, password: password);
      if (!mounted) return;

      widget.onNeedsFaceRegistration();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Tidak bisa terhubung ke server. Periksa baseUrl API.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAdminInfo() {
    _showMessage('Hubungi admin sistem untuk bantuan akun.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 20,
                  vertical: isWide ? 42 : 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Container(
                    padding: EdgeInsets.all(isWide ? 24 : 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: isWide
                        ? IntrinsicHeight(
                            child: Row(
                              children: [
                                const Expanded(child: _WelcomePanel()),
                                Container(
                                  width: 1,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 28),
                                  color: const Color(0xFFE7EAF0),
                                ),
                                Expanded(
                                  child: _LoginForm(
                                    loginController: _loginController,
                                    passwordController: _passwordController,
                                    isLoading: _isLoading,
                                    rememberMe: _rememberMe,
                                    obscurePassword: _obscurePassword,
                                    onRememberChanged: (value) => setState(
                                      () => _rememberMe = value ?? false,
                                    ),
                                    onTogglePassword: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                    onSubmit: _submit,
                                    onFaceRegistration: _openFaceRegistration,
                                    onContactAdmin: _showAdminInfo,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              const _WelcomePanel(compact: true),
                              const SizedBox(height: 26),
                              _LoginForm(
                                loginController: _loginController,
                                passwordController: _passwordController,
                                isLoading: _isLoading,
                                rememberMe: _rememberMe,
                                obscurePassword: _obscurePassword,
                                onRememberChanged: (value) => setState(
                                  () => _rememberMe = value ?? false,
                                ),
                                onTogglePassword: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                onSubmit: _submit,
                                onFaceRegistration: _openFaceRegistration,
                                onContactAdmin: _showAdminInfo,
                              ),
                            ],
                          ),
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

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 28,
        vertical: compact ? 0 : 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _LoginIllustration(),
          SizedBox(height: compact ? 22 : 28),
          Text(
            'Selamat Datang',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF253246),
              fontSize: compact ? 28 : 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: const Text(
              'Masuk ke akun Anda untuk mengakses sistem absensi pegawai.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF969CAF),
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginIllustration extends StatelessWidget {
  const _LoginIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F8FA),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFB7CFDA), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFDFF7F7), Color(0xFFFFF7D7)],
                ),
              ),
            ),
          ),
          const Positioned(
            top: 20,
            right: 84,
            child: _MonitorIcon(),
          ),
          const Positioned(
            top: 42,
            right: 14,
            child: _DocumentIcon(),
          ),
          Positioned(
            right: 12,
            bottom: 16,
            child: Transform.rotate(
              angle: 0.06,
              child: Container(
                width: 96,
                height: 190,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF7FB),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFF31546A), width: 4),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 50,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF31546A),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: const Color(0xFF86D5E7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF15445A),
                        size: 34,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6FFF1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF58B88B),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFF16815B),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            bottom: 10,
            child: SizedBox(
              width: 142,
              height: 220,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 92,
                      height: 130,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2B7BAA),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 28,
                    child: Container(
                      width: 90,
                      height: 86,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7A4735),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 52,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC69F),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF6A3B2D),
                          width: 3,
                        ),
                      ),
                      child: const Icon(
                        Icons.sentiment_satisfied_alt_rounded,
                        color: Color(0xFF6A3B2D),
                        size: 38,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    right: 3,
                    child: Transform.rotate(
                      angle: 0.08,
                      child: Container(
                        width: 74,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF7FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF31546A),
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: Color(0xFF2B7BAA),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 76,
                    left: 36,
                    child: Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 30,
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

class _MonitorIcon extends StatelessWidget {
  const _MonitorIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFAADBE2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7EA8B6), width: 2),
      ),
      child: const Icon(
        Icons.monitor_heart_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

class _DocumentIcon extends StatelessWidget {
  const _DocumentIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.article_outlined,
        color: Color(0xFF9BB8C4),
        size: 30,
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.loginController,
    required this.passwordController,
    required this.isLoading,
    required this.rememberMe,
    required this.obscurePassword,
    required this.onRememberChanged,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onFaceRegistration,
    required this.onContactAdmin,
  });

  final TextEditingController loginController;
  final TextEditingController passwordController;
  final bool isLoading;
  final bool rememberMe;
  final bool obscurePassword;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onFaceRegistration;
  final VoidCallback onContactAdmin;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Login Akun',
            style: TextStyle(
              color: Color(0xFF253246),
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Login untuk melanjutkan absensi atau pendaftaran wajah tanpa perlu masuk ulang setiap saat.',
            style: TextStyle(
              color: Color(0xFF969CAF),
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          const _FieldLabel(text: 'NIP / Username *'),
          const SizedBox(height: 9),
          _LoginTextField(
            controller: loginController,
            hintText: 'Masukkan NIP atau username',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 22),
          const _FieldLabel(text: 'Password *'),
          const SizedBox(height: 9),
          _LoginTextField(
            controller: passwordController,
            hintText: 'Masukkan password',
            icon: Icons.lock_outline_rounded,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLoading ? null : onSubmit(),
            suffix: IconButton(
              tooltip: obscurePassword
                  ? 'Tampilkan password'
                  : 'Sembunyikan password',
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: const Color(0xFF9AA3B5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: onRememberChanged,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: Color(0xFF8F98A8)),
                  activeColor: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Ingat saya di perangkat ini',
                  style: TextStyle(
                    color: Color(0xFF687386),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onFaceRegistration,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D4ED8),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('Pendaftaran wajah'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: isLoading ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('LOGIN'),
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Belum punya akun? ',
                  style: TextStyle(
                    color: Color(0xFF969CAF),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: onContactAdmin,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF1D4ED8),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: const Text('Hubungi Admin'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF253246),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.textInputAction,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Color(0xFF253246),
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF9BA3B4),
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF9AA3B5)),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
    );
  }
}
