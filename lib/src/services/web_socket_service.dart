part of '../../mongo_realtime.dart';

class RealtimeWebSocketService {
  RealtimeWebSocketService({required String url, this.authData}) : _url = url;

  String _url;
  RealtimeSocketConnection? _connection;
  StreamSubscription<dynamic>? _subscription;
  Future<void>? _connecting;
  bool _disposing = false;
  bool _connectionLossNotified = false;

  final StreamController<JsonMap> _messageController =
      StreamController<JsonMap>.broadcast();
  final StreamController<Object> _errorController =
      StreamController<Object>.broadcast();
  final StreamController<_RealtimeConnectionEvent> _connectionEventController =
      StreamController<_RealtimeConnectionEvent>.broadcast();

  String get url => _url;
  bool get isConnected => _connection != null;
  final Object? authData;
  Stream<JsonMap> get messages => _messageController.stream;
  Stream<Object> get errors => _errorController.stream;
  Stream<_RealtimeConnectionEvent> get _connectionEvents =>
      _connectionEventController.stream;

  Future<void> connect() async {
    if (_connection != null) {
      // _logInfo('WebSocket already connected to $_url.');
      return;
    }
    if (_connecting != null) {
      // _logInfo('WebSocket connection already in progress for $_url.');
      return _connecting!;
    }

    _logInfo('Connecting WebSocket to $_url...');

    final completer = Completer<void>();
    _connecting = completer.future;

    try {
      final connection = RealtimeSocketConnection.connect(
        Uri.parse(_url),
        authData,
      );
      _connection = connection;
      _connectionLossNotified = false;
      _subscription = connection.stream.listen(
        _handleIncoming,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );
      _logSuccess('WebSocket connected to $_url.');
      _connectionEventController.add(
        const _RealtimeConnectionEvent(_RealtimeConnectionEventType.connected),
      );
      completer.complete();
    } on Object catch (error, stackTrace) {
      _connection = null;
      _logError('WebSocket connection failed for $_url: $error');
      _connectionEventController.add(
        _RealtimeConnectionEvent(
          _RealtimeConnectionEventType.connectionFailed,
          error: error,
        ),
      );
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      _connecting = null;
    }
  }

  Future<void> reconnect({String? url}) async {
    if (url != null) {
      _url = url;
    }

    _logInfo('Reconnecting WebSocket to $_url...');
    await disconnect();
    await connect();
  }

  Future<void> send(JsonMap message) async {
    await connect();
    await _connection!.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    _disposing = true;
    final connection = _connection;
    _connection = null;

    await _subscription?.cancel();
    _subscription = null;

    if (connection != null) {
      _logInfo('Disconnecting WebSocket from $_url...');
      await connection.close();
    }

    _disposing = false;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _errorController.close();
    await _connectionEventController.close();
  }

  void _handleIncoming(dynamic payload) {
    try {
      final decoded = payload is String ? jsonDecode(payload) : payload;
      if (decoded is Map<dynamic, dynamic>) {
        _messageController.add(decoded.cast<String, dynamic>());
      } else {
        _errorController.add(
          StateError(
            'MongoRealtime expected a JSON object but received $decoded.',
          ),
        );
      }
    } on Object catch (error) {
      _errorController.add(error);
    }
  }

  void _handleSocketError(Object error, [StackTrace? stackTrace]) {
    _connection = null;
    _logError('WebSocket error on $_url: $error');
    _notifyConnectionLost(error);
  }

  void _handleSocketDone() {
    _connection = null;
    if (!_disposing) {
      _logError('WebSocket connection lost for $_url.');
      _notifyConnectionLost(
        StateError('MongoRealtime WebSocket connection closed unexpectedly.'),
      );
      return;
    }

    _logInfo('WebSocket closed for $_url.');
  }

  void _notifyConnectionLost(Object error) {
    if (_connectionLossNotified || _disposing) {
      return;
    }

    _connectionLossNotified = true;
    _connectionEventController.add(
      _RealtimeConnectionEvent(
        _RealtimeConnectionEventType.disconnected,
        error: error,
      ),
    );
  }

  void _logInfo(String message) {
    _Printer().write(message);
  }

  void _logSuccess(String message) {
    _Printer(_PrintType.success).write(message);
  }

  void _logError(String message) {
    _Printer(_PrintType.error).write(message);
  }
}

enum _RealtimeConnectionEventType { connected, disconnected, connectionFailed }

class _RealtimeConnectionEvent {
  const _RealtimeConnectionEvent(this.type, {this.error});

  final _RealtimeConnectionEventType type;
  final Object? error;
}
