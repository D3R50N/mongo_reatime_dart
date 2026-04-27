part of "../mongo_realtime.dart";

/// A listener instance to database or specific collections
class _RealtimeDB {
  final List<String?> _collections;
  final MongoRealtime _mongoRealtime;

  _RealtimeDB(this._mongoRealtime, List<String?> collections)
    : _collections = collections.where((t) => t != null).toList() {
    if (_collections.isEmpty) _collections.add(null);
  }

  /// Returns a collection-scoped accessor limited to [collection].
  _RealtimeCol col(String collection) =>
      _RealtimeCol(_mongoRealtime, collection);

  /// Listens to database changes for the configured collections.
  ///
  /// When [types] is empty, all change types are forwarded.
  /// When [callback] is provided, it is invoked for each matching event in
  /// addition to being emitted on the returned listener's stream.
  RealtimeListener onChange({
    List<RealtimeChangeType?> types = const [],
    void Function(RealtimeChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (final collection in _collections) {
      for (var type in types) {
        events.add(
          _mongoRealtime._buildEventName(collection: collection, type: type),
        );
      }
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }
}
