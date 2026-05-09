part of '../../mongo_realtime.dart';

/// A handle for a named collection on a MongoRealtime server.
///
/// Use this reference to query and mutate documents in the collection.
class RealtimeCollectionReference<T> {
  RealtimeCollectionReference({
    required MongoRealtime client,
    required String name,
    FromJson<T>? fromJson,
  }) : _client = client,
       _name = name,
       _fromJson = fromJson,
       watch = client.watch.copyWith(collection: name);

  final MongoRealtime _client;
  final String _name;
  final FromJson<T>? _fromJson;
  late final DbWatcher watch;

  /// The collection name.
  String get name => _name;

  /// Creates a query builder for this collection.
  ///
  /// Optionally provide [filter], [sort], and [limit] to initialize the query.
  RealtimeQueryBuilder<T> query({
    JsonMap? filter,
    Map<String, int>? sort,
    int? limit,
  }) {
    return RealtimeQueryBuilder<T>(
      client: _client,
      collection: _name,
      fromJson: _fromJson,
      filter: filter,
      sort: sort,
      limit: limit,
    );
  }

  /// Adds a filter clause to the query for the specified [field].
  ///
  /// The returned query builder can be used to chain further filters,
  /// sorting, and query execution.
  RealtimeQueryBuilder<T> where(
    String field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterOrEqualTo,
    Object? isLowerThan,
    Object? isLowerOrEqualTo,
    Object? arrayContains,
    Iterable? isIn,
    Object? matches,
  }) {
    return query().where(
      field,
      isEqualTo: isEqualTo,
      isNotEqualTo: isNotEqualTo,
      isGreaterThan: isGreaterThan,
      isGreaterOrEqualTo: isGreaterOrEqualTo,
      isLowerThan: isLowerThan,
      isLowerOrEqualTo: isLowerOrEqualTo,
      arrayContains: arrayContains,
      isIn: isIn,
      matches: matches,
    );
  }

  /// Adds an `$or` clause to the query using the provided [build] callback.
  RealtimeQueryBuilder<T> or(
    void Function(RealtimeQueryOrGroupBuilder group) build,
  ) {
    return query().or(build);
  }

  RealtimeQueryBuilder<T> sort(String field, {bool descending = false}) {
    return query().sort(field, descending: descending);
  }

  RealtimeQueryBuilder<T> take(int limit) => query().take(limit);

  RealtimeQueryBuilder<T> limit(int limit) => query().limit(limit);

  /// Subscribes to realtime updates for this collection.
  Stream<List<RealtimeDocument<T>>> get stream {
    return query().stream;
  }

  /// Fetches the current documents matching the optional [filter], [sort], and [limit].
  Future<List<RealtimeDocument<T>>> find({
    JsonMap? filter,
    Map<String, int>? sort,
    int? limit,
  }) {
    return query(filter: filter, sort: sort, limit: limit).find();
  }

  /// Returns a reference to a single document by [id].
  RealtimeDocumentReference<T> doc(String id) {
    return RealtimeDocumentReference<T>(
      client: _client,
      collection: _name,
      id: id,
      fromJson: _fromJson,
    );
  }

  /// Inserts a new [document] into the collection.
  ///
  /// Use [optimistic] to apply the change locally before server confirmation.
  Future<void> insert(JsonMap document, {bool optimistic = false}) {
    return _client.insert(_name, document, optimistic: optimistic);
  }

  /// Performs an update on all documents matching the query filter using MongoDB update operators.
  /// The update will be applied atomically on the server. If `optimistic` is true, the cache will be updated immediately with the expected changes, and then reconciled with the server response when it arrives. If `optimistic` is false, the cache will only be updated when the server confirms the update.
  /// The `update` parameter should be a map containing MongoDB update operators like `$set`, `$unset`, `$inc`, `$push`, `$pull`, `$addToSet`, and `$rename`.
  Future<void> update({
    JsonMap? $set,
    JsonMap? $unset,
    JsonMap? $inc,
    JsonMap? $push,
    JsonMap? $pull,
    JsonMap? $addToSet,
    JsonMap? $rename,
    JsonMap? additionalUpdate,
    JsonMap? filter,
    bool optimistic = false,
  }) {
    final update = buildUpdateMap(
      set: $set,
      unset: $unset,
      inc: $inc,
      push: $push,
      pull: $pull,
      addToSet: $addToSet,
      rename: $rename,
      additionalUpdate: additionalUpdate,
    );

    return _client.update(
      _name,
      update: update,
      filter: filter ?? <String, dynamic>{},
      optimistic: optimistic,
    );
  }

  /// Deletes documents from the collection matching [filter].
  Future<void> delete({JsonMap? filter, bool optimistic = false}) {
    return _client.delete(
      _name,
      filter: filter ?? <String, dynamic>{},
      optimistic: optimistic,
    );
  }
}
