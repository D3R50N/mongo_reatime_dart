part of '../../mongo_realtime.dart';

class RealtimeQueryManager {
  RealtimeQueryManager({
    required RealtimeCacheManager cacheManager,
    required RealtimeWebSocketService webSocketService,
  }) : _cacheManager = cacheManager,
       _webSocketService = webSocketService;

  final RealtimeCacheManager _cacheManager;
  final RealtimeWebSocketService _webSocketService;
  final Map<String, RealtimeLiveQuery> _queries = {};
  final Map<String, List<_PendingFetch>> _pendingFetches = {};
  final Map<String, List<ChangeHandler>> _dbChangeHandlers = {};

  Stream<List<RealtimeDocument<T>>> streamQuery<T>(
    RealtimeQueryDefinition definition, {
    FromJson<T>? fromJson,
  }) {
    final liveQuery = _queries.putIfAbsent(
      definition.queryId,
      () => RealtimeLiveQuery(definition),
    );

    return Stream.multi((controller) {
      final streamSubscription = liveQuery.stream.listen(
        (documents) {
          controller.add(_toDocuments(documents, fromJson));
        },
        onError: controller.addError,
        onDone: controller.close,
      );

      liveQuery.listenerCount += 1;
      if (liveQuery.listenerCount == 1) {
        unawaited(_subscribe(liveQuery));
      }

      if (liveQuery.hasSnapshot) {
        controller.add(_toDocuments(liveQuery.documents, fromJson));
      }

      controller.onCancel = () async {
        await streamSubscription.cancel();
        liveQuery.listenerCount -= 1;

        if (liveQuery.listenerCount <= 0) {
          liveQuery.listenerCount = 0;
          liveQuery.clearSnapshot();
          _cacheManager.releaseQuery(liveQuery.definition.queryId);
          await _unsubscribe(liveQuery);
          if (liveQuery.listenerCount == 0 &&
              identical(_queries[liveQuery.definition.queryId], liveQuery)) {
            _queries.remove(liveQuery.definition.queryId);
            await liveQuery.dispose();
          }
        }
      };
    }, isBroadcast: true);
  }

  Stream<RealtimeDocument<T>?> streamDocument<T>({
    required String collection,
    required String id,
    FromJson<T>? fromJson,
  }) {
    final definition = RealtimeQueryDefinition.document(
      collection: collection,
      id: id,
    );
    return streamQuery<T>(
      definition,
      fromJson: fromJson,
    ).map((documents) => documents.isEmpty ? null : documents.first);
  }

  Future<List<RealtimeDocument<T>>> fetchQuery<T>(
    RealtimeQueryDefinition definition, {
    FromJson<T>? fromJson,
  }) async {
    final completer = Completer<List<JsonMap>>();
    _pendingFetches
        .putIfAbsent(definition.queryId, () => <_PendingFetch>[])
        .add(_PendingFetch(definition: definition, completer: completer));

    await _webSocketService.send(
      definition.toSubscriptionMessage('realtime:fetch'),
    );

    final documents = await completer.future;
    return _toDocuments(documents, fromJson);
  }

  Future<RealtimeDocument<T>?> fetchDocument<T>({
    required String collection,
    required String id,
    FromJson<T>? fromJson,
  }) async {
    final documents = await fetchQuery<T>(
      RealtimeQueryDefinition.document(collection: collection, id: id),
      fromJson: fromJson,
    );
    return documents.isEmpty ? null : documents.first;
  }

  Future<void> resubscribeActiveQueries() async {
    for (final liveQuery in _queries.values) {
      if (liveQuery.listenerCount > 0) {
        await _subscribe(liveQuery);
      }
    }
  }

  void _registerDbChangeHandler(String changeKey, ChangeHandler handler) {
    _dbChangeHandlers
        .putIfAbsent(changeKey, () => <ChangeHandler>[])
        .add(handler);
  }

  void _removeDbChangeHandler(String changeKey, ChangeHandler handler) {
    final handlers = _dbChangeHandlers[changeKey];
    if (handlers != null) {
      handlers.remove(handler);
      if (handlers.isEmpty) {
        _dbChangeHandlers.remove(changeKey);
      }
    }
  }

  void applyInitial(String queryId, List<JsonMap> documents) {
    final pendingFetches = _pendingFetches.remove(queryId);
    if (pendingFetches != null) {
      for (final pendingFetch in pendingFetches) {
        pendingFetch.completer.complete(
          _normalizeQueryResult(documents, definition: pendingFetch.definition),
        );
      }
    }

    final liveQuery = _queries[queryId];
    if (liveQuery == null || liveQuery.listenerCount <= 0) {
      return;
    }

    final next = _normalizeQueryResult(
      documents,
      definition: liveQuery.definition,
    );
    _replaceLiveQueryDocuments(liveQuery, next, forceEmit: true);
  }

  void applyInsert(String collection, JsonMap document) {
    for (final liveQuery in _queries.values) {
      if (liveQuery.listenerCount <= 0 ||
          liveQuery.definition.collection != collection) {
        continue;
      }

      _applyDocumentChange(liveQuery, current: document);
    }
  }

  void applyUpdate({
    required String collection,
    JsonMap? previous,
    required JsonMap current,
  }) {
    for (final liveQuery in _queries.values) {
      if (liveQuery.listenerCount <= 0 ||
          liveQuery.definition.collection != collection) {
        continue;
      }

      _applyDocumentChange(liveQuery, previous: previous, current: current);
    }
  }

  void applyDelete({required String collection, required String id}) {
    for (final liveQuery in _queries.values) {
      if (liveQuery.listenerCount <= 0 ||
          liveQuery.definition.collection != collection) {
        continue;
      }

      final next = liveQuery.documents
          .where((document) => document['_id']?.toString() != id)
          .toList(growable: false);

      _replaceLiveQueryDocuments(
        liveQuery,
        _backfillFromCache(liveQuery, next, excludedIds: <String>{id}),
      );
    }
  }

  void applyDbChange(String changeKey, RealtimeDbChange change) {
    final handlers = _dbChangeHandlers[changeKey];
    if (handlers != null) {
      for (final handler in handlers) {
        handler(change);
      }
    }
  }

  void applyDeleteByFilter({
    required String collection,
    required JsonMap filter,
  }) {
    final documents = _cacheManager.matchingDocuments(collection, filter);
    for (final document in documents) {
      final id = document['_id']?.toString();
      if (id != null && id.isNotEmpty) {
        applyDelete(collection: collection, id: id);
      }
    }
  }

  void applyRemoteOperatorUpdate({
    required String collection,
    required JsonMap filter,
    required JsonMap update,
  }) {
    final documents = _cacheManager.matchingDocuments(collection, filter);
    for (final previous in documents) {
      final current = applyMongoUpdate(previous, update);
      applyUpdate(collection: collection, previous: previous, current: current);
    }
  }

  void propagateError(Object error, {String? queryId}) {
    if (queryId != null) {
      _queries[queryId]?.addError(error);
      final pendingFetches = _pendingFetches.remove(queryId);
      if (pendingFetches != null) {
        for (final pendingFetch in pendingFetches) {
          pendingFetch.completer.completeError(error);
        }
      }
      return;
    }

    for (final liveQuery in _queries.values) {
      liveQuery.addError(error);
    }

    for (final pendingFetches in _pendingFetches.values) {
      for (final pendingFetch in pendingFetches) {
        pendingFetch.completer.completeError(error);
      }
    }
    _pendingFetches.clear();
  }

  void failPendingFetches(Object error) {
    for (final pendingFetches in _pendingFetches.values) {
      for (final pendingFetch in pendingFetches) {
        pendingFetch.completer.completeError(error);
      }
    }
    _pendingFetches.clear();
  }

  void optimisticInsert(String collection, JsonMap document) {
    applyInsert(collection, deepCopyMap(document));
  }

  void optimisticUpdate({
    required String collection,
    required JsonMap filter,
    required JsonMap update,
  }) {
    applyRemoteOperatorUpdate(
      collection: collection,
      filter: filter,
      update: update,
    );
  }

  void optimisticDelete({required String collection, required JsonMap filter}) {
    applyDeleteByFilter(collection: collection, filter: filter);
  }

  Future<void> dispose() async {
    for (final liveQuery in _queries.values) {
      await liveQuery.dispose();
    }
    _queries.clear();

    for (final pendingFetches in _pendingFetches.values) {
      for (final pendingFetch in pendingFetches) {
        pendingFetch.completer.completeError(
          StateError(
            'MongoRealtime query manager was disposed before fetch completed.',
          ),
        );
      }
    }
    _pendingFetches.clear();
  }

  Future<void> _subscribe(RealtimeLiveQuery liveQuery) {
    return _webSocketService.send(
      liveQuery.definition.toSubscriptionMessage('realtime:subscribe'),
    );
  }

  Future<void> _unsubscribe(RealtimeLiveQuery liveQuery) {
    return _webSocketService.send(
      liveQuery.definition.toSubscriptionMessage('realtime:unsubscribe'),
    );
  }

  void _applyDocumentChange(
    RealtimeLiveQuery liveQuery, {
    JsonMap? previous,
    required JsonMap current,
  }) {
    final query = liveQuery.definition;
    final currentId = current['_id']?.toString();
    if (currentId == null || currentId.isEmpty) {
      return;
    }

    final next = liveQuery.documents.toList(growable: true);
    final previousIndex = next.indexWhere(
      (document) => document['_id']?.toString() == currentId,
    );

    final matchedBefore =
        previous != null
            ? matchesFilter(previous, query.filter)
            : previousIndex >= 0;
    final matchesNow = matchesFilter(current, query.filter);

    if (previousIndex >= 0) {
      next.removeAt(previousIndex);
    }

    if (matchesNow) {
      next.add(deepCopyMap(current));
    } else if (!matchedBefore) {
      return;
    }

    final finalized = _normalizeQueryResult(next, definition: query);
    final backfilled = _backfillFromCache(
      liveQuery,
      finalized,
      excludedIds: matchesNow ? const <String>{} : <String>{currentId},
    );
    _replaceLiveQueryDocuments(liveQuery, backfilled);
  }

  void _replaceLiveQueryDocuments(
    RealtimeLiveQuery liveQuery,
    List<JsonMap> documents, {
    bool forceEmit = false,
  }) {
    liveQuery.replaceDocuments(documents, forceEmit: forceEmit);
    _cacheManager.retainQuerySnapshot(
      liveQuery.definition.queryId,
      collection: liveQuery.definition.collection,
      documents: documents,
    );
  }

  List<JsonMap> _backfillFromCache(
    RealtimeLiveQuery liveQuery,
    List<JsonMap> seedDocuments, {
    Set<String> excludedIds = const <String>{},
  }) {
    final limit = liveQuery.definition.limit;
    if (limit == null || seedDocuments.length >= limit) {
      return seedDocuments;
    }

    final seedIds =
        seedDocuments
            .map((document) => document['_id']?.toString())
            .whereType<String>()
            .toSet();

    final candidates = <JsonMap>[
      ...seedDocuments.map(deepCopyMap),
      ..._cacheManager
          .matchingDocuments(
            liveQuery.definition.collection,
            liveQuery.definition.filter,
          )
          .where(
            (document) =>
                !seedIds.contains(document['_id']?.toString()) &&
                !excludedIds.contains(document['_id']?.toString()),
          ),
    ];

    return _normalizeQueryResult(candidates, definition: liveQuery.definition);
  }

  List<JsonMap> _normalizeQueryResult(
    Iterable<JsonMap> documents, {
    required RealtimeQueryDefinition definition,
  }) {
    return sortAndLimit(
      documents
          .where((document) => matchesFilter(document, definition.filter))
          .map(deepCopyMap),
      sort: definition.sort,
      limit: definition.limit,
    );
  }

  List<RealtimeDocument<T>> _toDocuments<T>(
    List<JsonMap> documents,
    FromJson<T>? fromJson,
  ) {
    return documents
        .map(
          (document) =>
              RealtimeDocument<T>.fromJson(document, fromJson: fromJson),
        )
        .toList(growable: false);
  }
}

class _PendingFetch {
  const _PendingFetch({required this.definition, required this.completer});

  final RealtimeQueryDefinition definition;
  final Completer<List<JsonMap>> completer;
}
