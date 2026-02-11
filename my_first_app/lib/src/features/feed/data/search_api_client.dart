import 'dart:convert';
import 'package:http/http.dart' as http;

class SearchApiClient {
  SearchApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = String.fromEnvironment(
    'HN_API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  Future<List<dynamic>> search(String query, {int? limit}) async {
    final uri = Uri.parse('$_baseUrl/v1/search').replace(
      queryParameters: {
        'q': query,
        if (limit != null) 'limit': '$limit',
      },
    );

    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Search request failed: ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected search response shape');
    }
    return decoded;
  }
}
