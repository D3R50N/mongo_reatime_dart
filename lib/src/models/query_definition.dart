part of '../../mongo_realtime.dart';

/// Represents a compiled query definition for realtime fetch and subscription.
///
/// This object is used internally to identify live query subscriptions and
/// to build the server request payload.
class RealtimeQueryDefinition {
  RealtimeQueryDefinition({
    required this.collection,
    JsonMap? filter,
    Map<String, int>? sort,
    this.limit,
  }) : filter = Map.unmodifiable(deepCopyMap(filter ?? const {})),
       sort = Map.unmodifiable(_normalizeSort(sort ?? const {})),
       queryId = _buildQueryId(
         collection: collection,
         filter: filter ?? const {},
         sort: sort ?? const {},
         limit: limit,
       );

  /// Creates a query definition for a single document based on its [id].
  factory RealtimeQueryDefinition.document({
    required String collection,
    required String id,
  }) {
    return RealtimeQueryDefinition(
      collection: collection,
      filter: {'_id': id},
      limit: 1,
    );
  }

  final String collection;
  final JsonMap filter;
  final Map<String, int> sort;
  final int? limit;
  final String queryId;

  /// Builds the JSON message used to subscribe or fetch this query.
  JsonMap toSubscriptionMessage(String type) {
    return {
      'type': type,
      'collection': collection,
      'filter': deepCopyMap(filter),
      'sort': Map<String, int>.from(sort),
      if (limit != null) 'limit': limit,
      'queryId': queryId,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RealtimeQueryDefinition &&
        other.collection == collection &&
        other.limit == limit &&
        canonicalQueryJsonEncode(other.filter) ==
            canonicalQueryJsonEncode(filter) &&
        orderedMapJsonEncode(other.sort) == orderedMapJsonEncode(sort);
  }

  @override
  int get hashCode => Object.hash(
    collection,
    canonicalQueryJsonEncode(filter),
    orderedMapJsonEncode(sort),
    limit,
  );

  static Map<String, int> _normalizeSort(Map<String, int> sort) {
    final normalized = <String, int>{};
    for (final entry in sort.entries) {
      normalized[entry.key] = entry.value < 0 ? -1 : 1;
    }
    return normalized;
  }

  static String _buildQueryId({
    required String collection,
    required JsonMap filter,
    required Map<String, int> sort,
    required int? limit,
  }) {
    final payload =
        '${canonicalQueryJsonEncode(<String, dynamic>{'collection': collection})}|'
        '${canonicalQueryJsonEncode(filter)}|'
        '${orderedMapJsonEncode(sort)}|'
        '${canonicalQueryJsonEncode(limit)}';
    return fnv1aHash(payload);
  }
}
