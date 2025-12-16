part of "../mongo_realtime.dart";

/// A listener instance to a specific collection
class _RealtimeCol {
  final String _collection;
  final MongoRealtime _mongoRealtime;

  _RealtimeCol(this._mongoRealtime, String collection)
    : _collection = collection;

  _RealtimeDoc doc(String docId) =>
      _RealtimeDoc(_mongoRealtime, _collection, docId);

  RealtimeListener onChange({
    List<RealtimeChangeType?> types = const [],
    void Function(RealtimeChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (var type in types) {
      events.add(
        _mongoRealtime._buildEventName(collection: _collection, type: type),
      );
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }
}
