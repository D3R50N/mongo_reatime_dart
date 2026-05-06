part of '../../mongo_realtime.dart';

class RealtimeEventProcessor {
  RealtimeEventProcessor({
    required RealtimeWebSocketService webSocketService,
    required RealtimeQueryManager queryManager,
    required void Function(String requestId, Object? data) onEmitResult,
    required void Function(String requestId, Object error) onEmitError,
  }) : _queryManager = queryManager,
       _onEmitResult = onEmitResult,
       _onEmitError = onEmitError {
    _messageSubscription = webSocketService.messages.listen(_handleMessage);
    _errorSubscription = webSocketService.errors.listen(
      (error) => _queryManager.failPendingFetches(error),
    );
  }

  final RealtimeQueryManager _queryManager;
  final void Function(String requestId, Object? data) _onEmitResult;
  final void Function(String requestId, Object error) _onEmitError;
  late final StreamSubscription<JsonMap> _messageSubscription;
  late final StreamSubscription<Object> _errorSubscription;

  Future<void> dispose() async {
    await _messageSubscription.cancel();
    await _errorSubscription.cancel();
  }

  void _handleMessage(JsonMap message) {
    final type = message['type']?.toString();
    switch (type) {
      case 'realtime:initial':
        final queryId = message['queryId']?.toString();
        if (queryId == null) {
          return;
        }
        _queryManager.applyInitial(queryId, _readDocuments(message));
        return;
      case 'realtime:insert':
        final collection = message['collection']?.toString();
        final document = _readDocument(message);
        if (collection != null && document != null) {
          _queryManager.applyInsert(collection, document);
        }
        return;
      case 'realtime:update':
        _handleUpdate(message);
        return;
      case 'realtime:delete':
        _handleDelete(message);
        return;
      case 'realtime:error':
        _queryManager.propagateError(
          Exception(
            message['error']?.toString() ??
                message['message']?.toString() ??
                'MongoRealtime server error.',
          ),
          queryId: message['queryId']?.toString(),
        );
        return;
      case 'realtime:emit:result':
        final requestId = message['requestId']?.toString();
        if (requestId != null) {
          _onEmitResult(requestId, message['data']);
        }
        return;
      case 'realtime:emit:error':
        final requestId = message['requestId']?.toString();
        if (requestId != null) {
          _onEmitError(
            requestId,
            StateError(
              message['error']?.toString() ??
                  'MongoRealtime custom event failed.',
            ),
          );
        }
        return;
      case 'realtime:db:change':
        _handleDbChange(message);
        return;
    }
  }

  void _handleDbChange(JsonMap message) {
    try {
      final changeKey = message['key']!.toString();
      final change = RealtimeDbChange.fromJson(message);
      _queryManager.applyDbChange(changeKey, change);
    } catch (_) {}
  }

  void _handleUpdate(JsonMap message) {
    final collection = message['collection']?.toString();
    if (collection == null) {
      return;
    }

    final current = _readDocument(message);
    if (current != null) {
      final previous = _readNamedDocument(message, 'before');
      _queryManager.applyUpdate(
        collection: collection,
        previous: previous,
        current: current,
      );
      return;
    }

    final filter = _readNamedDocument(message, 'filter');
    final update = _readNamedDocument(message, 'update');
    if (filter != null && update != null) {
      _queryManager.applyRemoteOperatorUpdate(
        collection: collection,
        filter: filter,
        update: update,
      );
    }
  }

  void _handleDelete(JsonMap message) {
    final collection = message['collection']?.toString();
    if (collection == null) {
      return;
    }

    final id =
        message['documentId']?.toString() ??
        message['id']?.toString() ??
        _readDocument(message)?['_id']?.toString() ??
        (_readNamedDocument(message, 'filter')?['_id']?.toString());

    if (id != null && id.isNotEmpty) {
      _queryManager.applyDelete(collection: collection, id: id);
      return;
    }

    final filter = _readNamedDocument(message, 'filter');
    if (filter != null) {
      _queryManager.applyDeleteByFilter(collection: collection, filter: filter);
    }
  }

  List<JsonMap> _readDocuments(JsonMap message) {
    final payload = message['documents'] ?? message['data'];
    if (payload is! List<dynamic>) {
      return const [];
    }

    return payload
        .whereType<Map<dynamic, dynamic>>()
        .map((document) => document.cast<String, dynamic>())
        .toList(growable: false);
  }

  JsonMap? _readDocument(JsonMap message) {
    return _readNamedDocument(message, 'document') ??
        _readNamedDocument(message, 'data') ??
        _readNamedDocument(message, 'after');
  }

  JsonMap? _readNamedDocument(JsonMap message, String key) {
    final payload = message[key];
    if (payload is Map<dynamic, dynamic>) {
      return payload.cast<String, dynamic>();
    }
    return null;
  }
}
