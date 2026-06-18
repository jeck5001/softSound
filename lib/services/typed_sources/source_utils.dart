import 'dart:convert';

import '../../data/models/source_rule.dart';

class SourceUtils {
  const SourceUtils._();

  static String stableId(String sourceId, String value) {
    final bytes = utf8.encode('$sourceId:$value');
    var hash = 0x811c9dc5;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return '${sourceId}_${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static String chapterId(String bookId, int index) => '${bookId}_$index';

  static String? absoluteUrl(String baseUrl, String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final value = path.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';
    final base = Uri.parse(baseUrl);
    if (value.startsWith('/')) {
      return '${base.scheme}://${base.host}$value';
    }
    return '${baseUrl.replaceFirst(RegExp(r"/$"), '')}/$value';
  }

  static String? stringValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? intValue(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static dynamic valueAt(Map<String, dynamic> json, List<String> path) {
    dynamic current = json;
    for (final key in path) {
      if (current is! Map) return null;
      current = current[key];
    }
    return current;
  }

  static String? stringAt(Map<String, dynamic> json, List<List<String>> paths) {
    for (final path in paths) {
      final value = valueAt(json, path);
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Map<String, dynamic>? decodeLooseJsonObject(String response) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) return null;
    final strict = _tryDecodeJson(trimmed);
    if (strict != null) return strict;
    return _tryDecodeJson(_quoteSingleQuotedJson(trimmed));
  }

  static Map<String, dynamic>? _tryDecodeJson(String response) {
    try {
      final decoded = jsonDecode(response);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static String _quoteSingleQuotedJson(String response) {
    final buffer = StringBuffer();
    var inSingle = false;
    var inDouble = false;
    var escaped = false;

    for (var i = 0; i < response.length; i++) {
      final char = response[i];
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (char == '"' && !inSingle) {
        inDouble = !inDouble;
        buffer.write(char);
        continue;
      }

      if (char == "'" && !inDouble) {
        inSingle = !inSingle;
        buffer.write('"');
        continue;
      }

      buffer.write(char);
    }

    return buffer.toString();
  }

  static Map<String, String> headers(SourceRule source) {
    return {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      ...?source.header,
    };
  }
}
