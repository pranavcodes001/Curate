import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/app_state.dart';

class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const _keyToken = 'auth_token';
  static const _keyRefreshToken = 'refresh_token';
  late final SharedPreferences _prefs;

  final ValueNotifier<String?> token = ValueNotifier<String?>(null);
  String? _refreshToken;

  bool get isLoggedIn => token.value != null && token.value!.isNotEmpty;
  String? get refreshToken => _refreshToken;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    token.value = _prefs.getString(_keyToken);
    _refreshToken = _prefs.getString(_keyRefreshToken);
  }

  Future<void> setToken(String? value) async {
    await setTokens(value, refreshToken: _refreshToken);
  }

  Future<void> setTokens(String? accessToken, {String? refreshToken}) async {
    token.value = accessToken;
    _refreshToken = refreshToken;
    if (accessToken == null) {
      await _prefs.remove(_keyToken);
    } else {
      await _prefs.setString(_keyToken, accessToken);
    }
    if (refreshToken == null) {
      await _prefs.remove(_keyRefreshToken);
    } else {
      await _prefs.setString(_keyRefreshToken, refreshToken);
    }
  }

  Future<void> clear() async {
    token.value = null;
    _refreshToken = null;
    await _prefs.remove(_keyToken);
    await _prefs.remove(_keyRefreshToken);
    // Explicitly wipe local profile data on logout to prevent cross-account leaks
    await AppState.instance.clearUserProfile();
  }
}
