part of '../../mongo_realtime.dart';

class RealtimeWebSocketService {
  RealtimeWebSocketService({required String url, this.authData}) : _url = url;

  String _url;
  WebSocketChannel? _channel;
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
  bool get isConnected => _channel != null;
  final Object? authData;
  Stream<JsonMap> get messages => _messageController.stream;
  Stream<Object> get errors => _errorController.stream;
  Stream<_RealtimeConnectionEvent> get _connectionEvents =>
      _connectionEventController.stream;

  Future<void> connect() async {
    if (_channel != null) {
      return;
    }
    if (_connecting != null) {
      return _connecting!;
    }

    _connecting = _connectInternal();
    try {
      await _connecting!;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _connectInternal() async {
    _logInfo('Connecting WebSocket to $_url...');

    try {
      final channel = IOWebSocketChannel.connect(
        Uri.parse(_url),
        headers: _buildHeaders(authData),
      );
      await channel.ready;
      _channel = channel;
      _connectionLossNotified = false;
      _subscription = channel.stream.listen(
        _handleIncoming,
        onError: _handleSocketError,
        onDone: _handleSocketDone,
        cancelOnError: false,
      );
      _logSuccess('WebSocket connected to $_url.');
      _connectionEventController.add(
        const _RealtimeConnectionEvent(_RealtimeConnectionEventType.connected),
      );
    } on Object catch (error) {
      _channel = null;
      await _subscription?.cancel();
      _subscription = null;
      _logError('WebSocket connection failed for $_url: $error');
      _connectionEventController.add(
        _RealtimeConnectionEvent(
          _RealtimeConnectionEventType.connectionFailed,
          error: error,
        ),
      );
      rethrow;
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
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> disconnect() async {
    _disposing = true;
    final channel = _channel;
    _channel = null;

    await _subscription?.cancel();
    _subscription = null;

    if (channel != null) {
      _logInfo('Disconnecting WebSocket from $_url...');
      await channel.sink.close();
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
    _channel = null;
    _logError('WebSocket error on $_url: $error');
    _notifyConnectionLost(error);
  }

  void _handleSocketDone() {
    _channel = null;
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

  Map<String, Object> _buildHeaders(Object? authData) {
    final encodedAuthData = _encodeAuthData(authData);
    if (encodedAuthData == null) {
      return const <String, Object>{};
    }
    return <String, Object>{'auth': encodedAuthData};
  }

  String? _encodeAuthData(Object? authData) {
    if (authData == null) {
      return null;
    }
    if (authData is Map) {
      return jsonEncode(authData);
    }
    if (authData is Iterable) {
      return jsonEncode({
        for (var i = 0; i < authData.length; i++) '$i': authData.elementAt(i),
      });
    }
    return authData.toString();
  }
}

enum _RealtimeConnectionEventType { connected, disconnected, connectionFailed }

class _RealtimeConnectionEvent {
  const _RealtimeConnectionEvent(this.type, {this.error});

  final _RealtimeConnectionEventType type;
  final Object? error;
}
