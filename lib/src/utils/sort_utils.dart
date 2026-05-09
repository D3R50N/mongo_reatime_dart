part of '../../mongo_realtime.dart';

/// Builds a comparator for sorting documents by specified field orders.
///
/// The [sort] map contains field names as keys and 1 (ascending) or -1
/// (descending) as values.
Comparator<JsonMap> buildSortComparator(Map<String, int> sort) {
  return (left, right) {
    for (final entry in sort.entries) {
      final leftValue = readPath(left, entry.key);
      final rightValue = readPath(right, entry.key);
      final comparison = compareJsonValues(leftValue, rightValue);
      if (comparison != 0) {
        return entry.value < 0 ? -comparison : comparison;
      }
    }

    return compareJsonValues(left['_id']?.toString(), right['_id']?.toString());
  };
}

/// Sorts documents and applies a limit if needed.
List<JsonMap> sortAndLimit(
  Iterable<JsonMap> documents, {
  required Map<String, int> sort,
  required int? limit,
}) {
  final sorted = documents.toList(growable: true);
  if (sort.isNotEmpty) {
    sorted.sort(buildSortComparator(sort));
  }
  if (limit == null || limit >= sorted.length) {
    return sorted;
  }
  return sorted.take(limit).toList(growable: false);
}
