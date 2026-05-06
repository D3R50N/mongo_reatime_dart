part of '../../mongo_realtime.dart';

class RealtimeCacheManager {
  final Map<String, Map<String, JsonMap>> _collections = {};

  JsonMap? getDocument(String collection, String id) {
    final document = _collections[collection]?[id];
    return document == null ? null : deepCopyMap(document);
  }

  List<JsonMap> allDocuments(String collection) {
    final documents = _collections[collection]?.values ?? const <JsonMap>[];
    return documents.map(deepCopyMap).toList(growable: false);
  }

  List<JsonMap> matchingDocuments(String collection, JsonMap filter) {
    return allDocuments(collection)
        .where((document) => matchesFilter(document, filter))
        .toList(growable: false);
  }

  void upsert(String collection, JsonMap document) {
    final id = document['_id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    final bucket =
        _collections.putIfAbsent(collection, () => <String, JsonMap>{});
    bucket[id] = deepCopyMap(document);
  }

  JsonMap? delete(String collection, String id) {
    final removed = _collections[collection]?.remove(id);
    return removed == null ? null : deepCopyMap(removed);
  }

  void clear() {
    _collections.clear();
  }
}
