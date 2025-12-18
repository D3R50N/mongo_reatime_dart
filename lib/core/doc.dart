part of "../mongo_realtime.dart";

/// A listener instance to a specific documet
class _RealtimeDoc {
  final String _collection;
  final String _docId;
  final MongoRealtime _mongoRealtime;

  _RealtimeDoc(this._mongoRealtime, String collection, String docId)
    : _collection = collection,
      _docId = docId;

  RealtimeListener onChange({
    List<RealtimeChangeType?> types = const [],
    void Function(RealtimeChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (var type in types) {
      events.add(
        _mongoRealtime._buildEventName(
          collection: _collection,
          type: type,
          docId: _docId,
        ),
      );
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }

  Future find<T>({T Function(Map<String, dynamic> doc)? map}) async {
    final data =
        await _RealtimeCol(
              _mongoRealtime,
              _collection,
            )._emitFindEvent(id: _docId)
            as Map<String, dynamic>?;

    if (map == null) return data;
    if (data == null) return null;

    return map(data);
  }

  Future<int> update<T>({
    Map<String, dynamic>? $set,
    Map<String, dynamic>? $inc,
    Map<String, dynamic>? $unset,
    Map<String, dynamic>? $push,
    Map<String, dynamic>? $pull,
    Map<String, dynamic>? $addToSet,
    Map<String, dynamic>? $rename,
    Map<String, dynamic>? $setOnInsert,
  }) async {
    final updateData = (
      $set: $set,
      $inc: $inc,
      $unset: $unset,
      $push: $push,
      $pull: $pull,
      $addToSet: $addToSet,
      $rename: $rename,
      $setOnInsert: $setOnInsert,
    );
    return await _RealtimeCol(
      _mongoRealtime,
      _collection,
    )._emitUpdateEvent(update: updateData, force: true, id: _docId);
  }
}
