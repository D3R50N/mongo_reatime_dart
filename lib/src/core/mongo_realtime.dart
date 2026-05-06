part of '../../mongo_realtime.dart';

class MongoRealtime {
  MongoRealtime._({
    required String normalizedUrl,
    WarningHandler? warningHandler,
    Object? authData,
  }) : _warningHandler = warningHandler ?? _defaultWarningHandler {
    _authData = authData;
    _webSocketService = RealtimeWebSocketService(
      url: normalizedUrl,
      authData: _authData,
    );
    _cacheManager = RealtimeCacheManager();
    _queryManager = RealtimeQueryManager(
      cacheManager: _cacheManager,
      webSocketService: _webSocketService,
    );
    watch = DbWatcher(queryManager: _queryManager);
    _eventProcessor = RealtimeEventProcessor(
      webSocketService: _webSocketService,
      queryManager: _queryManager,
      onEmitResult: _completeEmit,
      onEmitError: _failEmit,
    );
    _connectionEventSubscription = _webSocketService._connectionEvents.listen(
      _handleConnectionEvent,
    );
  }

  factory MongoRealtime(
    String url, {
    WarningHandler? warningHandler,
    Object? authData,
  }) {
    final normalized = normalizeWebSocketUrl(url);
    final instance = MongoRealtime._(
      normalizedUrl: normalized.url,
      warningHandler: warningHandler,
      authData: authData,
    );
    instance._warn(normalized.warning);
    return instance;
  }

  static MongoRealtime? _instance;
  static String _defaultUrl = 'ws://localhost:3000';
  static Object? _defaultAuthData;
  static WarningHandler? _defaultWarningHandlerOverride;

  static MongoRealtime get instance {
    return _instance ??= MongoRealtime._createDefault();
  }

  static MongoRealtime connect(
    String url, {
    WarningHandler? warningHandler,
    Object? authData,
  }) {
    final normalized = normalizeWebSocketUrl(url);
    _defaultUrl = normalized.url;
    _defaultWarningHandlerOverride =
        warningHandler ?? _defaultWarningHandlerOverride;
    _defaultAuthData = authData;

    final previous = _instance;
    final instance = MongoRealtime._createDefault();
    _instance = instance;
    instance._warn(normalized.warning);
    unawaited(instance._openInitialConnection());

    if (previous != null && !identical(previous, instance)) {
      unawaited(previous.dispose());
    }

    return instance;
  }

  static MongoRealtime _createDefault() {
    return MongoRealtime._(
      normalizedUrl: _defaultUrl,
      warningHandler: _defaultWarningHandlerOverride,
      authData: _defaultAuthData,
    );
  }

  final WarningHandler _warningHandler;
  late final Object? _authData;
  late final RealtimeWebSocketService _webSocketService;
  late final RealtimeCacheManager _cacheManager;
  late final RealtimeQueryManager _queryManager;
  late final DbWatcher watch;
  late final RealtimeEventProcessor _eventProcessor;
  late final StreamSubscription<_RealtimeConnectionEvent>
  _connectionEventSubscription;
  Timer? _reconnectTimer;
  bool _reconnectInProgress = false;
  bool _shouldResubscribeAfterReconnect = false;
  bool _disposed = false;
  int _requestCounter = 0;
  final Map<String, Completer<Object?>> _pendingEmits =
      <String, Completer<Object?>>{};

  static void _defaultWarningHandler(String message) {
    _Printer._printWarning(message);
  }

  String get url => _webSocketService.url;

  RealtimeCollectionReference<T> collection<T>(
    String name, {
    FromJson<T>? fromJson,
  }) {
    return RealtimeCollectionReference<T>(
      client: this,
      name: name,
      fromJson: fromJson,
    );
  }

  Future<void> reconnect([String? url]) async {
    if (url != null) {
      final normalized = normalizeWebSocketUrl(url);
      _warn(normalized.warning);
      await _webSocketService.reconnect(url: normalized.url);
    } else {
      await _webSocketService.reconnect();
    }

    await _queryManager.resubscribeActiveQueries();
  }

  Future<void> insert(
    String collection,
    JsonMap document, {
    bool optimistic = false,
  }) async {
    final payload = deepCopyMap(document);
    await _webSocketService.send({
      'type': 'realtime:insert',
      'collection': collection,
      'document': payload,
    });

    if (optimistic && payload['_id'] != null) {
      _queryManager.optimisticInsert(collection, payload);
    }
  }

  Future<void> update(
    String collection, {
    required JsonMap update,
    required JsonMap filter,
    bool optimistic = false,
  }) async {
    final updatePayload = deepCopyMap(update);
    final filterPayload = deepCopyMap(filter);

    await _webSocketService.send({
      'type': 'realtime:update',
      'collection': collection,
      'filter': filterPayload,
      'update': updatePayload,
    });

    if (optimistic) {
      _queryManager.optimisticUpdate(
        collection: collection,
        filter: filterPayload,
        update: updatePayload,
      );
    }
  }

  Future<void> delete(
    String collection, {
    required JsonMap filter,
    bool optimistic = false,
  }) async {
    final filterPayload = deepCopyMap(filter);

    await _webSocketService.send({
      'type': 'realtime:delete',
      'collection': collection,
      'filter': filterPayload,
    });

    if (optimistic) {
      _queryManager.optimisticDelete(
        collection: collection,
        filter: filterPayload,
      );
    }
  }

  Future<Object?> emit(String event, [Object? payload]) async {
    final requestId = _nextRequestId();
    final completer = Completer<Object?>();
    _pendingEmits[requestId] = completer;

    try {
      await _webSocketService.send({
        'type': 'realtime:emit',
        'event': event,
        'requestId': requestId,
        'payload': payload,
      });
    } on Object catch (error, stackTrace) {
      _pendingEmits.remove(requestId);
      completer.completeError(error, stackTrace);
    }

    return completer.future;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _connectionEventSubscription.cancel();
    _failPendingEmits(
      StateError('MongoRealtime was disposed before emit completed.'),
    );
    await _eventProcessor.dispose();
    await _queryManager.dispose();
    _cacheManager.clear();
    await _webSocketService.dispose();
  }

  Future<void> _openInitialConnection() async {
    try {
      await _webSocketService.connect();
    } on Object {
      // Connection failures are already routed to the printer and error stream.
    }
  }

  void _handleConnectionEvent(_RealtimeConnectionEvent event) {
    switch (event.type) {
      case _RealtimeConnectionEventType.connected:
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _reconnectInProgress = false;

        if (_shouldResubscribeAfterReconnect) {
          _shouldResubscribeAfterReconnect = false;
          unawaited(_queryManager.resubscribeActiveQueries());
        }
        return;
      case _RealtimeConnectionEventType.disconnected:
      case _RealtimeConnectionEventType.connectionFailed:
        if (_disposed) {
          return;
        }

        _failPendingEmits(
          StateError(
            'MongoRealtime connection was lost before emit completed.',
          ),
        );
        _shouldResubscribeAfterReconnect = true;
        _scheduleReconnect();
        return;
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectInProgress || _reconnectTimer != null) {
      return;
    }

    _reconnectTimer = Timer(const Duration(seconds: 1), () {
      _reconnectTimer = null;
      unawaited(_attemptReconnect());
    });
  }

  Future<void> _attemptReconnect() async {
    if (_disposed || _reconnectInProgress) {
      return;
    }

    _reconnectInProgress = true;
    try {
      await _webSocketService.connect();
    } on Object {
      if (!_disposed) {
        _scheduleReconnect();
      }
    } finally {
      _reconnectInProgress = false;
    }
  }

  void _completeEmit(String requestId, Object? data) {
    final completer = _pendingEmits.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.complete(data);
    }
  }

  void _failEmit(String requestId, Object error, [StackTrace? stackTrace]) {
    final completer = _pendingEmits.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  void _failPendingEmits(Object error, [StackTrace? stackTrace]) {
    for (final completer in _pendingEmits.values) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
    _pendingEmits.clear();
  }

  String _nextRequestId() {
    _requestCounter += 1;
    return 'emit_${DateTime.now().microsecondsSinceEpoch}_$_requestCounter';
  }

  void _warn(String? warning) {
    if (warning == null || warning.isEmpty) {
      return;
    }
    _warningHandler(warning);
  }
}

/// Helper function to access the singleton instance of [MongoRealtime].
MongoRealtime get realtime => MongoRealtime.instance;
