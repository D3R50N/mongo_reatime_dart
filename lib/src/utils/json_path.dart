part of '../../mongo_realtime.dart';

/// Reads the value at [path] from a JSON document using dot notation.
///
/// Returns null if the path does not exist. Paths like 'user.name' will
/// navigate through nested objects.
Object? readPath(JsonMap json, String path) {
  if (path.isEmpty) {
    return json;
  }

  Object? current = json;
  for (final segment in path.split('.')) {
    if (current is Map<dynamic, dynamic>) {
      current = current[segment];
    } else {
      return null;
    }
  }

  return current;
}

/// Sets the value at [path] in a JSON document using dot notation.
///
/// Creates intermediate objects as needed. Paths like 'user.profile.age'
/// will create nested objects if they don't exist.
void writePath(JsonMap json, String path, Object? value) {
  final segments = path.split('.');
  JsonMap current = json;

  for (var index = 0; index < segments.length - 1; index++) {
    final segment = segments[index];
    final next = current[segment];
    if (next is Map<dynamic, dynamic>) {
      current = next.cast<String, dynamic>();
      continue;
    }

    final replacement = <String, dynamic>{};
    current[segment] = replacement;
    current = replacement;
  }

  current[segments.last] = value;
}
