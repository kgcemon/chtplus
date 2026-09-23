/// Defensive readers for API maps.
///
/// MySQL sends numbers as ints, decimals as strings and booleans as 0/1
/// depending on the column, so every model parses through these instead of
/// casting and risking a runtime type error on one unusual row.
extension JsonMap on Map<String, dynamic> {
  String str(String key, {String fallback = ''}) {
    final value = this[key];
    if (value == null) return fallback;
    return value.toString();
  }

  String? strOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int intOr(String key, [int fallback = 0]) {
    final value = this[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    if (value is bool) return value ? 1 : 0;
    return fallback;
  }

  int? intOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    return null;
  }

  double dbl(String key, [double fallback = 0]) {
    final value = this[key];
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  bool flag(String key, {bool fallback = false}) {
    final value = this[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == 'true' || v == '1' || v == 'yes';
    }
    return fallback;
  }

  DateTime? date(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  List<String> stringList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, dynamic>? mapOrNull(String key) {
    final value = this[key];
    return value is Map<String, dynamic> ? value : null;
  }

  List<Map<String, dynamic>> mapList(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
}

/// Turns a decoded JSON array into typed models, skipping anything malformed.
List<T> parseList<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
  if (body is! List) return const [];
  final result = <T>[];
  for (final item in body) {
    if (item is Map<String, dynamic>) result.add(fromJson(item));
  }
  return result;
}
