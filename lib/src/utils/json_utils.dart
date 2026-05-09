part of '../../mongo_realtime.dart';

/// Creates a deep copy of a JSON-style map.
///
/// This copies nested maps and lists recursively to preserve immutability.
JsonMap deepCopyMap(Map<dynamic, dynamic> source) {
  return source.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), deepCopyJson(value)),
  );
}

/// Creates a deep copy of a JSON-compatible value.
Object? deepCopyJson(Object? value) {
  if (value is Map<dynamic, dynamic>) {
    return deepCopyMap(value);
  }
  if (value is List<dynamic>) {
    return value.map(deepCopyJson).toList(growable: false);
  }
  return value;
}

/// Performs a deep equality comparison for JSON-style values.
bool deepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is Map && right is Map) {
    if (left.length != right.length) {
      return false;
    }
    for (final key in left.keys) {
      if (!right.containsKey(key) || !deepEquals(left[key], right[key])) {
        return false;
      }
    }
    return true;
  }
  if (left is List && right is List) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!deepEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

/// Encodes an object to JSON with deterministic key ordering.
///
/// This is useful for stable hash generation and comparison of query payloads.
String stableJsonEncode(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    final encoded = keys
        .map((key) => '${jsonEncode(key)}:${stableJsonEncode(value[key])}')
        .join(',');
    return '{$encoded}';
  }
  if (value is List) {
    final encoded = value.map(stableJsonEncode).join(',');
    return '[$encoded]';
  }
  return jsonEncode(value);
}

/// Encodes query payloads in a canonical form for deterministic comparison.
String canonicalQueryJsonEncode(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    final encoded = keys
        .map((key) {
          final child = value[key];
          if (_isUnorderedQueryArrayKey(key) && child is List<dynamic>) {
            final values = child
              .map(canonicalQueryJsonEncode)
              .toList(growable: true)..sort();
            return '${jsonEncode(key)}:[${values.join(',')}]';
          }

          return '${jsonEncode(key)}:${canonicalQueryJsonEncode(child)}';
        })
        .join(',');
    return '{$encoded}';
  }
  if (value is List) {
    final encoded = value.map(canonicalQueryJsonEncode).join(',');
    return '[$encoded]';
  }
  return jsonEncode(value);
}

/// Encodes a map into a JSON-like representation that preserves insertion order.
String orderedMapJsonEncode(Map<String, dynamic> value) {
  final encoded = value.entries
      .map(
        (entry) =>
            '[${jsonEncode(entry.key)},${canonicalQueryJsonEncode(entry.value)}]',
      )
      .join(',');
  return '[$encoded]';
}

bool _isUnorderedQueryArrayKey(String key) {
  return key == r'$and' ||
      key == r'$or' ||
      key == r'$nor' ||
      key == r'$in' ||
      key == r'$nin';
}

/// Computes the FNV-1a hash for a string.
String fnv1aHash(String input) {
  const fnvPrime = 0x01000193;
  var hash = 0x811C9DC5;

  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }

  return hash.toRadixString(16).padLeft(8, '0');
}
