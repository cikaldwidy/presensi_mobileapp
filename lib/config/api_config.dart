import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Override dengan:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.12:8000/api
  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) {
      return _definedBaseUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  static const Duration timeout = Duration(seconds: 20);
}
