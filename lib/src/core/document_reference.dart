part of '../../mongo_realtime.dart';

/// A reference to a single document within a collection.
///
/// Use this reference to read, subscribe to, update, or delete the document.
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

  /// The document identifier.
  String get id => _id;

  /// A realtime stream that emits the document when it changes.
  Stream<RealtimeDocument<T>?> get stream {
    return _client._queryManager.streamDocument<T>(
      collection: _collection,
      id: _id,
      fromJson: _fromJson,
    );
  }

  /// Fetches the current state of the document once.
  Future<RealtimeDocument<T>?> find() {
    return _client._queryManager.fetchDocument<T>(
      collection: _collection,
      id: _id,
      fromJson: _fromJson,
    );
  }

  /// Performs an update on this document using MongoDB update operators.
  /// The update will be applied atomically on the server. If `optimistic` is true, the cache will be updated immediately with the expected changes, and then reconciled with the server response when it arrives. If `optimistic` is false, the cache will only be updated when the server confirms the update.
  /// The `update` parameter should be a map containing MongoDB update operators like `$set`, `$unset`, `$inc`, `$push`, `$pull`, `$addToSet`, and `$rename`.
  /// Updates this document with MongoDB update operators.
  ///
  /// Use [optimistic] to reconcile the local cache immediately before the
  /// server response is received.
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

  /// Deletes the document from its collection.
  ///
  /// When [optimistic] is true, the local cache removes the document
  /// immediately while awaiting server confirmation.
  Future<void> delete({bool optimistic = false}) {
    return _client.delete(
      _collection,
      filter: {'_id': _id},
      optimistic: optimistic,
    );
  }
}
