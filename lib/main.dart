import 'package:flutter/material.dart';

import 'screens/face_registration_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const PresensiApp());
}

class PresensiApp extends StatelessWidget {
  const PresensiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Presensi RS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7FAFA),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFFF7FAFA),
          foregroundColor: Color(0xFF243746),
          titleTextStyle: TextStyle(
            color: Color(0xFF243746),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2ECEB)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2ECEB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2ECEB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiService _apiService;
  late final AuthService _authService;
  late Future<_AuthDestination> _initialSession;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
    _authService = AuthService(_apiService);
    _initialSession = _resolveInitialSession();
  }

  Future<_AuthDestination> _resolveInitialSession() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      return _AuthDestination.login;
    }

    try {
      final user = await _authService.profile();
      return user.hasFaceEnrollment
          ? _AuthDestination.home
          : _AuthDestination.faceRegistration;
    } catch (_) {
      await _authService.logout();
      return _AuthDestination.login;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthDestination>(
      future: _initialSession,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == _AuthDestination.home) {
          return HomeScreen(
            apiService: _apiService,
            authService: _authService,
            onLogout: _showLogin,
          );
        }

        if (snapshot.data == _AuthDestination.faceRegistration) {
          return FaceRegistrationScreen(
            authService: _authService,
            onFinished: _showHome,
          );
        }

        return LoginScreen(
          authService: _authService,
          onLoggedIn: _showHome,
          onNeedsFaceRegistration: _showFaceRegistration,
        );
      },
    );
  }

  void _showHome() {
    setState(() {
      _initialSession = Future.value(_AuthDestination.home);
    });
  }

  void _showFaceRegistration() {
    setState(() {
      _initialSession = Future.value(_AuthDestination.faceRegistration);
    });
  }

  void _showLogin() {
    setState(() {
      _initialSession = Future.value(_AuthDestination.login);
    });
  }
}

enum _AuthDestination {
  login,
  faceRegistration,
  home,
}
