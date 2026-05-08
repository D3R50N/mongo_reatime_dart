part of '../../mongo_realtime.dart';

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

  String get name => _name;

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

  Stream<List<RealtimeDocument<T>>> get stream {
    return query().stream;
  }

  Future<List<RealtimeDocument<T>>> find({
    JsonMap? filter,
    Map<String, int>? sort,
    int? limit,
  }) {
    return query(filter: filter, sort: sort, limit: limit).find();
  }

  RealtimeDocumentReference<T> doc(String id) {
    return RealtimeDocumentReference<T>(
      client: _client,
      collection: _name,
      id: id,
      fromJson: _fromJson,
    );
  }

  Future<void> insert(JsonMap document, {bool optimistic = false}) {
    return _client.insert(_name, document, optimistic: optimistic);
  }

  Future<void> update(
    JsonMap update, {
    JsonMap? filter,
    bool optimistic = false,
  }) {
    return _client.update(
      _name,
      update: update,
      filter: filter ?? <String, dynamic>{},
      optimistic: optimistic,
    );
  }

  Future<void> delete({JsonMap? filter, bool optimistic = false}) {
    return _client.delete(
      _name,
      filter: filter ?? <String, dynamic>{},
      optimistic: optimistic,
    );
  }
}
