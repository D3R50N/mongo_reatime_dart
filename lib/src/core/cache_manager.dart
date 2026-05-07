part of '../../mongo_realtime.dart';

class RealtimeCacheManager {
  final Map<String, Map<String, JsonMap>> _collections = {};
  final Map<String, _RetainedQuerySnapshot> _querySnapshots = {};
  final Map<String, Map<String, int>> _referenceCounts = {};

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

  void retainQuerySnapshot(
    String queryId, {
    required String collection,
    required Iterable<JsonMap> documents,
  }) {
    final nextDocuments = <String, JsonMap>{};
    for (final document in documents) {
      final id = document['_id']?.toString();
      if (id == null || id.isEmpty) {
        continue;
      }
      nextDocuments[id] = deepCopyMap(document);
    }

    final previous = _querySnapshots[queryId];
    if (previous != null) {
      _releaseStaleReferences(
        previous,
        nextCollection: collection,
        nextDocumentIds: nextDocuments.keys.toSet(),
      );
    }

    if (nextDocuments.isEmpty) {
      _querySnapshots.remove(queryId);
      return;
    }

    final bucket = _collections.putIfAbsent(
      collection,
      () => <String, JsonMap>{},
    );
    for (final entry in nextDocuments.entries) {
      if (previous == null ||
          previous.collection != collection ||
          !previous.documentIds.contains(entry.key)) {
        _incrementReference(collection, entry.key);
      }
      bucket[entry.key] = deepCopyMap(entry.value);
    }

    _querySnapshots[queryId] = _RetainedQuerySnapshot(
      collection: collection,
      documentIds: nextDocuments.keys.toSet(),
    );
  }

  void releaseQuery(String queryId) {
    final snapshot = _querySnapshots.remove(queryId);
    if (snapshot == null) {
      return;
    }

    _releaseSnapshot(snapshot);
  }

  void clear() {
    _collections.clear();
    _querySnapshots.clear();
    _referenceCounts.clear();
  }

  void _releaseStaleReferences(
    _RetainedQuerySnapshot snapshot, {
    required String nextCollection,
    required Set<String> nextDocumentIds,
  }) {
    final removedIds =
        snapshot.collection == nextCollection
            ? snapshot.documentIds.difference(nextDocumentIds)
            : snapshot.documentIds;
    if (removedIds.isEmpty) {
      return;
    }

    _releaseSnapshot(
      _RetainedQuerySnapshot(
        collection: snapshot.collection,
        documentIds: removedIds,
      ),
    );
  }

  void _releaseSnapshot(_RetainedQuerySnapshot snapshot) {
    for (final id in snapshot.documentIds) {
      _decrementReference(snapshot.collection, id);
    }
  }

  void _incrementReference(String collection, String id) {
    final collectionReferences = _referenceCounts.putIfAbsent(
      collection,
      () => <String, int>{},
    );
    collectionReferences[id] = (collectionReferences[id] ?? 0) + 1;
  }

  void _decrementReference(String collection, String id) {
    final collectionReferences = _referenceCounts[collection];
    if (collectionReferences == null) {
      _collections[collection]?.remove(id);
      if (_collections[collection]?.isEmpty ?? false) {
        _collections.remove(collection);
      }
      return;
    }

    final nextCount = (collectionReferences[id] ?? 0) - 1;
    if (nextCount > 0) {
      collectionReferences[id] = nextCount;
      return;
    }

    collectionReferences.remove(id);
    if (collectionReferences.isEmpty) {
      _referenceCounts.remove(collection);
    }

    final documents = _collections[collection];
    documents?.remove(id);
    if (documents != null && documents.isEmpty) {
      _collections.remove(collection);
    }
  }
}

class _RetainedQuerySnapshot {
  const _RetainedQuerySnapshot({
    required this.collection,
    required this.documentIds,
  });

  final String collection;
  final Set<String> documentIds;
}
