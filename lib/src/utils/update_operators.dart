part of '../../mongo_realtime.dart';

bool isMongoOperatorUpdate(JsonMap update) {
  return update.keys.any((key) => key.startsWith(r'$'));
}

JsonMap applyMongoUpdate(JsonMap original, JsonMap update) {
  final working = deepCopyMap(original);

  if (!isMongoOperatorUpdate(update)) {
    for (final entry in update.entries) {
      writePath(working, entry.key, deepCopyJson(entry.value));
    }
    return working;
  }

  for (final entry in update.entries) {
    final payload = (entry.value as Map<dynamic, dynamic>? ?? const {})
        .cast<String, dynamic>();

    switch (entry.key) {
      case r'$set':
        for (final updateEntry in payload.entries) {
          writePath(working, updateEntry.key, deepCopyJson(updateEntry.value));
        }
        break;
      case r'$inc':
        for (final updateEntry in payload.entries) {
          final current = readPath(working, updateEntry.key);
          final currentNumber = current is num ? current : 0;
          final delta = updateEntry.value is num ? updateEntry.value as num : 0;
          writePath(working, updateEntry.key, currentNumber + delta);
        }
        break;
      case r'$addToSet':
        for (final updateEntry in payload.entries) {
          final list = _readOrCreateList(working, updateEntry.key);
          final values = _expandUpdateValue(updateEntry.value);
          for (final value in values) {
            if (!list.any((item) => deepEquals(item, value))) {
              list.add(deepCopyJson(value));
            }
          }
        }
        break;
      case r'$push':
        for (final updateEntry in payload.entries) {
          final list = _readOrCreateList(working, updateEntry.key);
          final values = _expandUpdateValue(updateEntry.value);
          list.addAll(values.map(deepCopyJson));
        }
        break;
      case r'$pull':
        for (final updateEntry in payload.entries) {
          final list = _readOrCreateList(working, updateEntry.key);
          final condition = updateEntry.value;
          list.removeWhere((item) => _shouldPull(item, condition));
        }
        break;
    }
  }

  return working;
}

List<dynamic> _readOrCreateList(JsonMap document, String path) {
  final current = readPath(document, path);
  if (current is List<dynamic>) {
    return current;
  }

  final replacement = <dynamic>[];
  writePath(document, path, replacement);
  return replacement;
}

List<dynamic> _expandUpdateValue(Object? value) {
  if (value is Map<dynamic, dynamic> && value.containsKey(r'$each')) {
    return List<dynamic>.from(value[r'$each'] as List<dynamic>? ?? const []);
  }
  return [value];
}

bool _shouldPull(Object? item, Object? condition) {
  if (condition is Map<dynamic, dynamic>) {
    final mapCondition = condition.cast<String, dynamic>();
    if (item is Map<dynamic, dynamic>) {
      return matchesFilter(
        item.cast<String, dynamic>(),
        mapCondition,
      );
    }
  }

  return deepEquals(item, condition);
}
