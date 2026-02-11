import '../models/auth_token.dart';

abstract class AuthRepository {
  Future<AuthToken> login({required String email, required String password});
  Future<AuthToken> adminLogin({required String username, required String password});
  Future<void> register({required String email, required String password});
}
