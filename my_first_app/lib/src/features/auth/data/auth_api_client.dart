import 'dart:convert';
import '../../../core/network/api_client.dart';

class AuthApiClient {
  AuthApiClient({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await _api.post(
      '/v1/auth/login',
      body: {'email': email, 'password': password},
    );
    if (resp.statusCode != 200) {
      throw Exception('Login failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected login response');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> adminLogin(String username, String password) async {
    final resp = await _api.post(
      '/v1/auth/admin/login',
      body: {'username': username, 'password': password},
    );
    if (resp.statusCode != 200) {
      throw Exception('Admin login failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected admin login response');
    }
    return decoded;
  }

  Future<void> register(String email, String password) async {
    final resp = await _api.post(
      '/v1/auth/register',
      body: {'email': email, 'password': password},
    );
    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw Exception('Register failed: ${resp.statusCode}');
    }
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final resp = await _api.post(
      '/v1/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
    if (resp.statusCode != 200) {
      throw Exception('Refresh failed: ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected refresh response');
    }
    return decoded;
  }
}
