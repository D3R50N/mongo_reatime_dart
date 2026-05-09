part of '../../mongo_realtime.dart';

/// Checks if a document matches a MongoDB-style filter.
bool matchesFilter(JsonMap document, JsonMap filter) {
  if (filter.isEmpty) {
    return true;
  }

  for (final entry in filter.entries) {
    final key = entry.key;
    final condition = entry.value;

    if (key == r'$and') {
      final clauses = (condition as List<dynamic>? ?? const []);
      if (!clauses.every(
        (clause) => matchesFilter(
          document,
          (clause as Map<dynamic, dynamic>).cast<String, dynamic>(),
        ),
      )) {
        return false;
      }
      continue;
    }

    if (key == r'$or') {
      final clauses = (condition as List<dynamic>? ?? const []);
      if (!clauses.any(
        (clause) => matchesFilter(
          document,
          (clause as Map<dynamic, dynamic>).cast<String, dynamic>(),
        ),
      )) {
        return false;
      }
      continue;
    }

    if (key == r'$nor') {
      final clauses = (condition as List<dynamic>? ?? const []);
      if (clauses.any(
        (clause) => matchesFilter(
          document,
          (clause as Map<dynamic, dynamic>).cast<String, dynamic>(),
        ),
      )) {
        return false;
      }
      continue;
    }

    final value = readPath(document, key);
    if (!_matchesCondition(value, condition)) {
      return false;
    }
  }

  return true;
}

bool _matchesCondition(Object? value, Object? condition) {
  if (condition is Map<dynamic, dynamic>) {
    final operators = condition.cast<String, dynamic>();
    if (operators.keys.any((key) => key.startsWith(r'$'))) {
      if (operators.containsKey(r'$regex') &&
          !_matchesRegex(value, operators[r'$regex'], operators[r'$options'])) {
        return false;
      }

      for (final entry in operators.entries) {
        if (entry.key == r'$regex' || entry.key == r'$options') {
          continue;
        }
        if (!_applyOperator(value, entry.key, entry.value)) {
          return false;
        }
      }
      return true;
    }
  }

  if (value is List<dynamic>) {
    return value.any((item) => deepEquals(item, condition));
  }

  return deepEquals(value, condition);
}

bool _applyOperator(Object? value, String operator, Object? operand) {
  switch (operator) {
    case r'$eq':
      return deepEquals(value, operand);
    case r'$ne':
      return !deepEquals(value, operand);
    case r'$gt':
      return compareJsonValues(value, operand) > 0;
    case r'$gte':
      return compareJsonValues(value, operand) >= 0;
    case r'$lt':
      return compareJsonValues(value, operand) < 0;
    case r'$lte':
      return compareJsonValues(value, operand) <= 0;
    case r'$in':
      final values = operand as List<dynamic>? ?? const [];
      if (value is List<dynamic>) {
        return value.any(
          (item) => values.any((candidate) => deepEquals(item, candidate)),
        );
      }
      return values.any((candidate) => deepEquals(value, candidate));
    case r'$nin':
      final values = operand as List<dynamic>? ?? const [];
      if (value is List<dynamic>) {
        return value.every(
          (item) => values.every((candidate) => !deepEquals(item, candidate)),
        );
      }
      return values.every((candidate) => !deepEquals(value, candidate));
    case r'$exists':
      final shouldExist = operand == true;
      return shouldExist ? value != null : value == null;
    case r'$regex':
      return _matchesRegex(value, operand, null);
    case r'$contains':
      if (value is List<dynamic>) {
        return value.any((item) => deepEquals(item, operand));
      }
      if (value is String && operand is String) {
        return value.contains(operand);
      }
      return false;
    default:
      return true;
  }
}

bool _matchesRegex(Object? value, Object? pattern, Object? options) {
  if (value is! String || pattern == null) {
    return false;
  }

  final optionText = options?.toString() ?? '';
  return RegExp(
    pattern.toString(),
    caseSensitive: !optionText.contains('i'),
    multiLine: optionText.contains('m'),
  ).hasMatch(value);
}
