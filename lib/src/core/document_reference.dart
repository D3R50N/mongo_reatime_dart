part of '../../mongo_realtime.dart';

class RealtimeDocumentReference<T> {
  RealtimeDocumentReference({
    required MongoRealtime client,
    required String collection,
    required String id,
    FromJson<T>? fromJson,
  }) : _client = client,
       _collection = collection,
       _id = id,
       _fromJson = fromJson,
       watch = client.watch.copyWith(collection: collection, docId: id);

  final MongoRealtime _client;
  final String _collection;
  final String _id;
  final FromJson<T>? _fromJson;
  late final DbWatcher watch;

  String get id => _id;

  Stream<RealtimeDocument<T>?> get stream {
    return _client._queryManager.streamDocument<T>(
      collection: _collection,
      id: _id,
      fromJson: _fromJson,
    );
  }

  Future<RealtimeDocument<T>?> find() {
    return _client._queryManager.fetchDocument<T>(
      collection: _collection,
      id: _id,
      fromJson: _fromJson,
    );
  }

  Future<void> update({
    JsonMap? $set,
    JsonMap? $unset,
    JsonMap? $inc,
    JsonMap? $push,
    JsonMap? $pull,
    JsonMap? $addToSet,
    JsonMap? $rename,
    JsonMap? additionalUpdate,
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
      _collection,
      update: update,
      filter: {'_id': _id},
      optimistic: optimistic,
    );
  }

  Future<void> delete({bool optimistic = false}) {
    return _client.delete(
      _collection,
      filter: {'_id': _id},
      optimistic: optimistic,
    );
  }
}
