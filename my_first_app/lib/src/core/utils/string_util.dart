import 'package:html_unescape/html_unescape.dart';

class StringUtil {
  static final _unescape = HtmlUnescape();

  /// Unescapes HTML entities (e.g. &#x27; -> ') and strips common HTML tags.
  static String clean(String? input) {
    if (input == null || input.isEmpty) return '';

    // 1. Unescape characters
    var result = _unescape.convert(input);

    // 2. Remove common HTML tags like <p>, <a>, etc.
    // We'll use a simple regex for stripping tags if they are mixed in.
    result = result.replaceAll(RegExp(r'<[^>]*>'), ' ');

    // 3. Clean up extra whitespace
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}
