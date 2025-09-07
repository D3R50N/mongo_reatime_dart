import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart';

import 'core/printer.dart';
import 'mongo_change.dart';
import 'mongo_listener.dart';

export 'core/uuid.dart';
export 'mongo_change.dart';
export 'mongo_listener.dart';

/// A singleton-like service that connects to a backend via WebSocket
/// and dispatches MongoDB change events to listeners based on event names.
class MongoRealtime {
  static late MongoRealtime instance;

  late final Socket socket;
  final List<MongoListener> _listeners = [];
  final bool _showLogs;

  /// Creates and connects the MongoRealtime client.
  ///
  /// Listens for events prefixed with `db:` and routes them to matching listeners.
  MongoRealtime(
    String url, {
    String? token,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? authData,
    bool showLogs = true,
    bool autoConnect = false,
    void Function(dynamic data)? onConnect,
    void Function(dynamic reason)? onDisconnect,
    void Function(dynamic error)? onError,
    void Function(dynamic error)? onConnectError,
  }) : _showLogs = showLogs {
    OptionBuilder optionBuilder = OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': token, ...?authData})
        .enableForceNew()
        .enableForceNewConnection()
        .disableMultiplex()
        .disableReconnection()
        .setExtraHeaders(headers ?? {});

    if (!autoConnect) {
      optionBuilder = optionBuilder.disableAutoConnect();
    }

    socket = io(url, optionBuilder.build());

    socket.onConnect((data) {
      _log("Connected", PrintType.success);
      if (onConnect != null) onConnect(data);
    });

    socket.onDisconnect((reason) {
      _log("Disconnected ($reason)", PrintType.warning);
      if (onDisconnect != null) onDisconnect(reason);
    });

    socket.onError((error) {
      _log("Error ($error)", PrintType.error);
      if (onError != null) onError(error);
    });

    socket.onConnectError((error) {
      _log("Cannot connect ($error)", PrintType.error);
      if (onConnectError != null) onConnectError(error);
    });

    // Catch all db-related events and forward to matching listeners
    socket.onAny((event, data) {
      if (!event.startsWith('db:')) return;
      _log("Received '$event'");
      for (final listener in _listeners.where(
        (l) => l.events.contains(event),
      )) {
        final change = MongoChange.fromJson(data);
        listener.call(change);
      }
    });
  }

  /// Initializes and stores the singleton instance of [MongoRealtime].
  static MongoRealtime init(
    String url, {
    String? token,
    Map<String, dynamic>? headers,
    Map<String, dynamic>? authData,
    void Function(dynamic data)? onConnect,
    void Function(dynamic reason)? onDisconnect,
    void Function(dynamic error)? onError,
    void Function(dynamic error)? onConnectError,
    bool showLogs = true,
    bool autoConnect = false,
  }) {
    instance = MongoRealtime(
      url,
      token: token,
      headers: headers,
      onConnect: onConnect,
      onDisconnect: onDisconnect,
      onError: onError,
      authData: authData,
      autoConnect: autoConnect,
      onConnectError: onConnectError,
      showLogs: showLogs,
    );

    return instance;
  }

  /// Creates and registers a new [MongoListener] for a list of [events].
  MongoListener _createListener({
    List<String> events = const [],
    void Function(MongoChange change)? callback,
  }) {
    final controller = StreamController<MongoChange>();
    final listener = MongoListener(
      events: events,
      callback: callback,
      controller: controller,
    );

    // Set up cancellation logic
    listener.cancel = () {
      _listeners.removeWhere((l) => l.id == listener.id);
      controller.close();
    };

    _listeners.add(listener);

    return listener;
  }

  /// Logs a message to the console if [_showLogs] is enabled.
  void _log(String message, [PrintType? type]) {
    if (_showLogs) {
      Printer(type).write("[${"SOCKET ${socket.id ?? ""}".trim()}] $message");
    }
  }

  /// Builds a full event name from optional collection, document, and change type.
  ///
  /// Format: `db:<type>:<collection>:<docId>`
  String _buildEventName({
    String? collection,
    String? docId,
    MongoChangeType? type,
  }) {
    String ev = "db:";
    ev += type == null ? "change" : type.name;
    if (collection != null) ev += ":$collection";
    if (docId != null) ev += ":$docId";

    return ev;
  }

  void refreshAuthToken(String newToken) {
    socket.auth.token = newToken;
    reconnect();
  }

  void connect() {
    socket.connect();
  }

  void reconnect() {
    socket.disconnect().connect();
  }

  /// Listens for changes on a specific collection or document.
  ///
  /// Optionally filters by [docId] and/or [types].
  MongoListener onColChange(
    String collection, {
    String? docId,
    List<MongoChangeType?> types = const [],
    void Function(MongoChange change)? callback,
  }) {
    List<String> events = [];
    if (types.isEmpty) types.add(null);

    for (var type in types) {
      events.add(
        _buildEventName(collection: collection, type: type, docId: docId),
      );
    }

    final listener = _createListener(events: events, callback: callback);

    return listener;
  }

  /// Listens for changes across multiple collections and/or types.
  ///
  /// If no collection/type is specified, listens to all changes.
  MongoListener onDbChange({
    List<String?> collections = const [],
    List<MongoChangeType?> types = const [],
    void Function(MongoChange change)? callback,
  }) {
    List<String> events = [];

    types = types.where((t) => t != null).toList();
    collections = collections.where((t) => t != null).toList();

    if (types.isEmpty) types.add(null);
    if (collections.isEmpty) collections.add(null);

    for (final collection in collections) {
      for (var type in types) {
        events.add(_buildEventName(collection: collection, type: type));
      }
    }

    return _createListener(events: events, callback: callback);
  }
}

MongoRealtime get realtime => MongoRealtime.instance;
