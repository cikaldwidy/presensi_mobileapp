import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  AuthService(this._api);

  final ApiService _api;

  Future<UserModel> login({
    required String login,
    required String password,
  }) async {
    final response = await _api.post(
      '/login',
      body: {
        'login': login,
        'password': password,
        'device_name': 'flutter-android',
      },
    );

    final data = response['data'] as Map<String, dynamic>;
    await _api.saveToken(data['token'] as String);

    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<UserModel> profile() async {
    final response = await _api.get('/user/profile');
    return UserModel.fromJson(response['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> enrollFace({
    required List<String> images,
    required bool blinkVerified,
  }) {
    return _api.post(
      '/user/face-enrollment',
      body: {
        'images': images,
        'face_detected': true,
        'blink_verified': blinkVerified,
      },
    );
  }

  Future<bool> isLoggedIn() async {
    final token = await _api.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } finally {
      await _api.clearToken();
    }
  }
}
