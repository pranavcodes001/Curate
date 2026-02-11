import '../domain/models/auth_token.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthApiClient? apiClient})
      : _api = apiClient ?? AuthApiClient();

  final AuthApiClient _api;

  @override
  Future<AuthToken> login({required String email, required String password}) async {
    final raw = await _api.login(email, password);
    return AuthToken(
      accessToken: raw['access_token'] as String? ?? '',
      tokenType: raw['token_type'] as String? ?? 'bearer',
      refreshToken: raw['refresh_token'] as String?,
    );
  }

  @override
  Future<AuthToken> adminLogin({required String username, required String password}) async {
    final raw = await _api.adminLogin(username, password);
    return AuthToken(
      accessToken: raw['access_token'] as String? ?? '',
      tokenType: raw['token_type'] as String? ?? 'bearer',
      refreshToken: raw['refresh_token'] as String?,
    );
  }

  @override
  Future<void> register({required String email, required String password}) {
    return _api.register(email, password);
  }
}
