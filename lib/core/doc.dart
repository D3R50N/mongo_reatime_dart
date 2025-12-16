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
}
