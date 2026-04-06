// lib/services/auth_service.dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: AppConstants.apiTimeout,
  ));

  /// Daftar akun baru
  Future<Map<String, dynamic>> register({
    required String phoneNumber,
    required String name,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'phoneNumber': phoneNumber,
        'name': name,
        'password': password,
      });

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        await _saveToken(token);
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'error': response.data['error']};
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data['error'] ?? 'Gagal mendaftar'};
    }
  }

  /// Login ke akun yang sudah ada
  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'phoneNumber': phoneNumber,
        'password': password,
      });

      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        await _saveToken(token);
        return {'success': true, 'data': response.data['data']};
      }
      return {'success': false, 'error': response.data['error']};
    } on DioException catch (e) {
      return {'success': false, 'error': e.response?.data['error'] ?? 'Login gagal'};
    }
  }

  /// Verifikasi token saat app start
  Future<bool> verifyToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) return false;

    try {
      final response = await _dio.get('/auth/verify', options: Options(
        headers: {'Authorization': 'Bearer $token'}
      ));
      return response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
}
