part of '../../mongo_realtime.dart';

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
