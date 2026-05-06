part of '../../mongo_realtime.dart';

class DbWatcher {
  final String? _collection;
  final String? _docId;

  final RealtimeQueryManager _queryManager;

  String _buildChangeKey(RealtimeDbChangeType type) {
    String id = 'db:${type.name}';

    if (_collection != null && _collection.isNotEmpty) {
      id += ':$_collection';
    }
    if (_docId != null && _docId.isNotEmpty) {
      id += ':$_docId';
    }

    return id;
  }

  DbWatcher({
    String? collection,
    String? docId,
    required RealtimeQueryManager queryManager,
  })  : _queryManager = queryManager,
        _collection = collection,
        _docId = docId;

  DbWatcher copyWith({
    String? collection,
    String? docId,
  }) {
    return DbWatcher(
      collection: collection,
      docId: docId,
      queryManager: _queryManager,
    );
  }

  void _on(RealtimeDbChangeType type, ChangeHandler handler) {
    final changeKey = _buildChangeKey(type);
    _queryManager._registerDbChangeHandler(changeKey, handler);
  }

  void _off(RealtimeDbChangeType type, ChangeHandler handler) {
    final changeKey = _buildChangeKey(type);
    _queryManager._removeDbChangeHandler(changeKey, handler);
  }

  void onChange(ChangeHandler handler) {
    _on(RealtimeDbChangeType.change, handler);
  }

  void onInsert(ChangeHandler handler) {
    _on(RealtimeDbChangeType.insert, handler);
  }

  void onUpdate(ChangeHandler handler) {
    _on(RealtimeDbChangeType.update, handler);
  }

  void onDelete(ChangeHandler handler) {
    _on(RealtimeDbChangeType.delete, handler);
  }

  void offChange(ChangeHandler handler) {
    _off(RealtimeDbChangeType.change, handler);
  }

  void offInsert(ChangeHandler handler) {
    _off(RealtimeDbChangeType.insert, handler);
  }

  void offUpdate(ChangeHandler handler) {
    _off(RealtimeDbChangeType.update, handler);
  }

  void offDelete(ChangeHandler handler) {
    _off(RealtimeDbChangeType.delete, handler);
  }
}
