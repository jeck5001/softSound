/// 懒人听书网页（Nuxt SSR）内联数据解码器。
///
/// 契约来自聆阅字节码 #18036（`lrts-home`）与 #18090（`fetchLrtsChildren`），
/// 两者都是同一套做法：
///
/// ```js
/// const m = html.match(/window\.__NUXT__\s*=\s*([\s\S]*?);<\/script>/);
/// const payload = Function('return ' + m[1])();
/// payload.data[0]            // 或 payload.data
/// ```
///
/// 但 `window.__NUXT__` **不是 JSON**，它是 Nuxt 的压缩产物：
///
/// ```js
/// (function(a,b,c,...){return {data:[{title:"儿童",rootId:"6",...}]}}(
///   0,"",1,9.5,false,"支持听读劵",...
/// ));
/// ```
///
/// 即「参数名列表 + 返回字面量 + 实参列表」，字面量里所有重复出现的值都被换成了
/// 形参名（`a`=0、`b`=""、`c`=1……）。所以不能直接 `jsonDecode`。
///
/// 本文件实现一个**只读、无执行**的解码器：先解析形参/实参建立环境，
/// 再按环境把返回字面量求值成普通 Dart 值。不 eval、不执行任何页面代码。
///
/// 已实测支持：嵌套对象/数组、字符串（含 `\u002F` 转义）、整数/小数/负数、
/// `true`/`false`/`null`、`void 0`、`!0`/`!1`。
library;

/// `window.__NUXT__` 解码结果。
class NuxtPayload {
  const NuxtPayload(this.value);

  /// 解码后的根值（通常是 `Map`）。
  final Object? value;

  /// 从 HTML 中提取并解码 `window.__NUXT__`。
  ///
  /// 找不到、语法不认识或越界时返回 `null`（调用方按「无数据」处理，
  /// 绝不抛异常打断页面）。
  static NuxtPayload? tryParse(String html) {
    final match = RegExp(
      r'window\.__NUXT__\s*=\s*([\s\S]*?);</script>',
    ).firstMatch(html);
    if (match == null) return null;
    try {
      final decoded = _decodeExpression(match.group(1)!);
      if (decoded == null) return null;
      return NuxtPayload(decoded);
    } catch (_) {
      return null;
    }
  }

  /// 取 `data[0]`（Nuxt 页面通常是数组包一层；单对象也兼容）。
  ///
  /// 返回 `null` 表示结构不符。
  Map<String, dynamic>? get pageData {
    final root = value;
    if (root is! Map) return null;
    final data = root['data'];
    if (data is List) {
      if (data.isEmpty) return null;
      final first = data.first;
      return first is Map ? first.cast<String, dynamic>() : null;
    }
    if (data is Map) return data.cast<String, dynamic>();
    return null;
  }
}

// ---------------------------------------------------------------------------
// 解码实现
// ---------------------------------------------------------------------------

Object? _decodeExpression(String raw) {
  var expr = raw.trim();
  // APK 的正则捕获到 `;</script>` 之前，末尾会多一个 `)`。
  while (expr.endsWith(';')) {
    expr = expr.substring(0, expr.length - 1).trimRight();
  }
  if (expr.startsWith('(') && expr.endsWith(')')) {
    expr = expr.substring(1, expr.length - 1).trim();
  }

  const fnPrefix = 'function(';
  if (!expr.startsWith(fnPrefix)) {
    // 少数页面直接是对象字面量（无 IIFE）。退化处理：无环境求值。
    return _Parser(expr, const {}).parseValue();
  }

  final paramsEnd = expr.indexOf('){return');
  if (paramsEnd < 0) return null;
  final params = expr
      .substring(fnPrefix.length, paramsEnd)
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  final bodyStart = paramsEnd + '){return'.length;
  final callStart = expr.lastIndexOf('}(');
  if (callStart < bodyStart) return null;
  final body = expr.substring(bodyStart, callStart);

  var argsText = expr.substring(callStart + 2).trimRight();
  while (argsText.endsWith(')')) {
    argsText = argsText.substring(0, argsText.length - 1).trimRight();
  }

  final env = <String, Object?>{};
  final args = _splitTopLevel(argsText);
  for (var i = 0; i < params.length && i < args.length; i++) {
    env[params[i]] = _parseScalar(args[i]);
  }

  return _Parser(body, env).parseValue();
}

/// 顶层逗号切分（跳过字符串与括号内部）。
List<String> _splitTopLevel(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  var depth = 0;
  var inString = false;
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (inString) {
      buf.write(ch);
      if (ch == '\\' && i + 1 < s.length) {
        buf.write(s[i + 1]);
        i++;
      } else if (ch == '"') {
        inString = false;
      }
      continue;
    }
    if (ch == '"') {
      inString = true;
      buf.write(ch);
      continue;
    }
    if (ch == '{' || ch == '[' || ch == '(') depth++;
    if (ch == '}' || ch == ']' || ch == ')') depth--;
    if (ch == ',' && depth == 0) {
      out.add(buf.toString().trim());
      buf.clear();
      continue;
    }
    buf.write(ch);
  }
  final tail = buf.toString().trim();
  if (tail.isNotEmpty) out.add(tail);
  return out;
}

/// 实参只允许标量（数字 / 字符串 / 布尔 / null）。
Object? _parseScalar(String token) {
  final t = token.trim();
  if (t.isEmpty) return null;
  if (t.startsWith('"')) return _parseStringLiteral(t);
  if (t == 'true' || t == '!0') return true;
  if (t == 'false' || t == '!1') return false;
  if (t == 'null' || t == 'undefined' || t == 'void 0') return null;
  final n = num.tryParse(t);
  if (n != null) return n;
  return null;
}

String _parseStringLiteral(String t) {
  final buf = StringBuffer();
  var i = 1;
  while (i < t.length) {
    final ch = t[i];
    if (ch == '"') break;
    if (ch != '\\') {
      buf.write(ch);
      i++;
      continue;
    }
    i++;
    if (i >= t.length) break;
    final esc = t[i];
    switch (esc) {
      case 'n':
        buf.write('\n');
        i++;
      case 'r':
        buf.write('\r');
        i++;
      case 't':
        buf.write('\t');
        i++;
      case 'b':
        buf.write('\b');
        i++;
      case 'f':
        buf.write('\f');
        i++;
      case 'u':
        if (i + 4 < t.length) {
          final hex = t.substring(i + 1, i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code != null) buf.writeCharCode(code);
          i += 5;
        } else {
          i++;
        }
      case '"':
        buf.write('"');
        i++;
      case '\\':
        buf.write('\\');
        i++;
      case '/':
        buf.write('/');
        i++;
      default:
        buf.write(esc);
        i++;
    }
  }
  return buf.toString();
}

/// 返回字面量的递归下降解析器。
class _Parser {
  _Parser(this.src, this.env);

  final String src;
  final Map<String, Object?> env;
  int i = 0;

  void _ws() {
    while (i < src.length) {
      final c = src[i];
      if (c == ' ' || c == '\n' || c == '\r' || c == '\t') {
        i++;
      } else {
        break;
      }
    }
  }

  Never _fail(String what) => throw FormatException(
    'NUXT 解析失败（$what）@ $i: ${src.substring(i, i + 20 > src.length ? src.length : i + 20)}',
  );

  Object? parseValue() {
    _ws();
    if (i >= src.length) return null;
    final c = src[i];
    if (c == '{') return _object();
    if (c == '[') return _array();
    if (c == '"' || c == "'") return _string();
    if (c == '!') {
      // !0 / !1
      i++;
      final v = parseValue();
      return v == 0 || v == false ? true : false;
    }
    if (c == '-' || (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57)) {
      return _number();
    }
    return _identifier();
  }

  Object? _object() {
    i++; // {
    final out = <String, dynamic>{};
    while (true) {
      _ws();
      if (i >= src.length) _fail('object 未闭合');
      if (src[i] == '}') {
        i++;
        return out;
      }
      String key;
      if (src[i] == '"' || src[i] == "'") {
        key = _string();
      } else {
        final m = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').matchAsPrefix(src, i);
        if (m == null) _fail('object key');
        key = m.group(0)!;
        i = m.end;
      }
      _ws();
      if (i >= src.length || src[i] != ':') _fail('object 缺冒号');
      i++;
      out[key] = parseValue();
      _ws();
      if (i < src.length && src[i] == ',') {
        i++;
        continue;
      }
    }
  }

  List<dynamic> _array() {
    i++; // [
    final out = <dynamic>[];
    while (true) {
      _ws();
      if (i >= src.length) _fail('array 未闭合');
      if (src[i] == ']') {
        i++;
        return out;
      }
      out.add(parseValue());
      _ws();
      if (i < src.length && src[i] == ',') {
        i++;
        continue;
      }
    }
  }

  String _string() {
    final quote = src[i];
    i++;
    final buf = StringBuffer();
    while (i < src.length) {
      final ch = src[i];
      if (ch == quote) {
        i++;
        return buf.toString();
      }
      if (ch != '\\') {
        buf.write(ch);
        i++;
        continue;
      }
      i++;
      if (i >= src.length) break;
      final esc = src[i];
      switch (esc) {
        case 'n':
          buf.write('\n');
          i++;
        case 'r':
          buf.write('\r');
          i++;
        case 't':
          buf.write('\t');
          i++;
        case 'u':
          if (i + 4 < src.length) {
            final code = int.tryParse(src.substring(i + 1, i + 5), radix: 16);
            if (code != null) buf.writeCharCode(code);
            i += 5;
          } else {
            i++;
          }
        default:
          buf.write(esc);
          i++;
      }
    }
    return buf.toString();
  }

  num _number() {
    final m = RegExp(r'-?\d+(\.\d+)?([eE][+-]?\d+)?').matchAsPrefix(src, i);
    if (m == null) _fail('number');
    i = m.end;
    final text = m.group(0)!;
    return text.contains('.') || text.contains('e') || text.contains('E')
        ? double.parse(text)
        : int.parse(text);
  }

  Object? _identifier() {
    final m = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*').matchAsPrefix(src, i);
    if (m == null) _fail('identifier');
    final name = m.group(0)!;
    i = m.end;
    switch (name) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
        return null;
      case 'undefined':
        return null;
      case 'void':
        // `void 0`
        _ws();
        if (i < src.length && src[i] == '0') i++;
        return null;
    }
    if (env.containsKey(name)) return env[name];
    // 未知标识符：按 null 处理，避免整页解析失败。
    return null;
  }
}
