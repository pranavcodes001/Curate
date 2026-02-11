import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_session.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String baseUrl = String.fromEnvironment(
    'HN_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  Uri _uri(String path, [Map<String, String>? query]) {
    // Ensure no double slashes if baseUrl ends with /
    final safeBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final safePath = path.startsWith('/') ? path : '/$path';

    final uri = Uri.parse('$safeBase$safePath');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool auth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && AuthSession.instance.isLoggedIn) {
      headers['Authorization'] = 'Bearer ${AuthSession.instance.token.value}';
    }
    return headers;
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    bool auth = false,
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      auth: auth,
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, String>? query,
    Object? body,
    bool auth = false,
  }) {
    return _send(
      method: 'POST',
      path: path,
      query: query,
      body: body,
      auth: auth,
    );
  }

  Future<http.Response> _send({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    bool auth = false,
    bool allowRefresh = true,
  }) async {
    final uri = _uri(path, query);
    http.Response resp;
    if (method == 'POST') {
      resp = await _client.post(
        uri,
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      );
    } else {
      resp = await _client.get(uri, headers: _headers(auth: auth));
    }

    if (auth &&
        allowRefresh &&
        resp.statusCode == 401 &&
        AuthSession.instance.refreshToken != null) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        return _send(
          method: method,
          path: path,
          query: query,
          body: body,
          auth: auth,
          allowRefresh: false,
        );
      }
    }

    return resp;
  }

  Future<bool> _refreshToken() async {
    final refreshToken = AuthSession.instance.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final resp = await _client.post(
        _uri('/v1/auth/refresh'),
        headers: _headers(auth: false),
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (resp.statusCode != 200) {
        await AuthSession.instance.clear();
        return false;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        await AuthSession.instance.clear();
        return false;
      }
      final newAccess = decoded['access_token'] as String?;
      final newRefresh = decoded['refresh_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        await AuthSession.instance.clear();
        return false;
      }
      await AuthSession.instance.setTokens(
        newAccess,
        refreshToken: newRefresh ?? refreshToken,
      );
      return true;
    } catch (_) {
      await AuthSession.instance.clear();
      return false;
    }
  }
}
