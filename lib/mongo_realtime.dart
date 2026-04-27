library;
// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';

import 'package:flutter_reactive/flutter_reactive.dart';
import 'package:mongo_realtime/core/stream_data.dart';
import 'package:mongo_realtime/utils/uuid.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'utils/printer.dart';

export 'utils/uuid.dart';

part 'core/change.dart';
part 'core/col.dart';
part 'core/db.dart';
part 'core/doc.dart';
part 'core/event_data.dart';
part 'core/listener.dart';

/// A singleton-like service that connects to a backend via WebSocket
/// and dispatches MongoDB change events to listeners based on event names.
class MongoRealtime {
  static late MongoRealtime instance;

  late final Socket socket;
  final List<RealtimeListener> _listeners = [];
  final Map<String, Reactive<Map<String, dynamic>>> _cachedData = {};
  final Map<String, RealtimeStreamData> _streams = {};
  final Map<String, int> _streamSubscribers = {};
  final Map<String, void Function(dynamic map)> _streamHandlers = {};
  final bool _showLogs;

  bool _firstConnected = false;

  /// Delay in milliseconds before check if connected
  final int connectionDelay;

  /// Returns the Socket.IO server URI currently configured for this instance.
  String get uri => socket.io.uri;

  /// Whether the underlying socket is currently connected.
  bool get connected => socket.connected;

  static const String _minimumVersion = "2.0.4";

  int _compareVersions(String v) {
    final parts1 = _minimumVersion.split('.').map(int.parse).toList();
    final parts2 = v.split('.').map(int.parse).toList();

    final maxLength = [
      parts1.length,
      parts2.length,
    ].reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1.compareTo(p2);
    }

    return 0;
  }

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
    this.connectionDelay = 500,
  }) : _showLogs = showLogs {
    OptionBuilder optionBuilder =
        OptionBuilder().setTransports(['websocket']).setAuth({
            ...?authData,
            'token': token,
          }).disableAutoConnect()
          ..enableReconnection()
          ..setReconnectionDelayMax(1000).setExtraHeaders(headers ?? {});

    socket = io(url, optionBuilder.build());

    socket
      ..onConnect((data) {
        _log("Connected", PrintType.success);

        if (_firstConnected) {
          for (final data in _streams.values) {
            socket.emit("realtime", data.toMap());
          }
        } else {
          _firstConnected = true;
        }
        if (onConnect != null) onConnect(data);
      })
      ..onDisconnect((reason) {
        _log("Disconnected ($reason)", PrintType.warning);
        if (onDisconnect != null) onDisconnect(reason);
      })
      ..onError((error) {
        _log("Error ($error)", PrintType.error);
        if (onError != null) onError(error);
      })
      ..onConnectError((error) {
        _log("Cannot connect ($error)", PrintType.error);
        if (onConnectError != null) onConnectError(error);
      })
      ..onReconnect((_) {})
      ..onAny((event, data) {
        if (!event.startsWith('db:')) return;
        // _log("Received '$event'");
        for (final listener in _listeners.where(
          (l) => l._events.contains(event),
        )) {
          final change = RealtimeChange.fromJson(data);
          listener.call(change);
        }
      })
      ..on("version", (v) {
        if (_compareVersions(v) == 1) {
          Printer(PrintType.error).write(
            "[REALTIME] Server version ($v) doesn't satisfy the minimum $_minimumVersion",
          );
          socket.dispose();
        }
      });

    if (autoConnect) connect();
  }

  /// Returns a database-scoped accessor.
  ///
  /// When [collections] is omitted, listeners created from the returned object
  /// can observe events from every collection.
  _RealtimeDB db([List<String?> collections = const []]) =>
      _RealtimeDB(this, collections);

  /// Returns a collection-scoped accessor for [collection].
  _RealtimeCol col(String collection) => _RealtimeCol(this, collection);

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
    int connectionDelay = 500,
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
      connectionDelay: connectionDelay,
    );

    return instance;
  }

  /// Returns a stream of lists containing raw documents (`Map<String, dynamic>`).
  ///
  /// This is a convenience wrapper around [streamMapped] when no mapping is
  /// needed and the documents should be used as-is.
  ///
  /// Example:
  /// ```dart
  /// final stream = MongoRealtime.instance.stream("users");
  /// stream.listen((users) {
  ///   print(users); // List<Map<String, dynamic>>
  /// });
  /// ```

  Stream<List<Map<String, dynamic>>> stream(
    String streamId, {
    int? limit,
    bool Function(Map<String, dynamic> doc)? filter,
    Comparable Function(Map<String, dynamic> value)? sortBy,
    bool reverse = true,
  }) {
    return streamMapped<Map<String, dynamic>>(
      streamId,
      limit: limit,
      filter: filter,
      fromMap: (d) => d,
      sortBy: sortBy,
      reverse: reverse,
    );
  }

  /// Returns a stream of lists containing strongly-typed objects of type [T].
  ///
  /// Each document received from the socket is first converted from a
  /// `Map<String, dynamic>` using the provided [fromMap] function.
  /// You can also provide an optional [filter] function to exclude items from
  /// the list before it is emitted.
  ///
  /// Example:
  /// ```dart
  /// final stream = MongoRealtime.instance.streamMapped<User>(
  ///   "users",
  ///   fromMap: (doc) => User.fromJson(doc),
  ///   filter: (user) => user.age > 18,
  /// );
  ///
  /// stream.listen((users) {
  ///   print(users); // List<User> with age > 18
  /// });
  /// ```
  ///
  /// - [streamId]: Identifier of the stream (used in the socket event).
  /// - [fromMap]: A function that converts a raw document (`Map<String, dynamic>`)
  ///   into an instance of type [T].
  /// - [filter]: An optional function to include/exclude items from the list.
  /// - [sortBy]: An optional function to sort the list by an attribute.
  /// - [reverse]: Whether to sort the underlying document order descending by `_id`.
  /// - [limit]: Optional maximum number of items requested from the backend.

  Stream<List<T>> streamMapped<T>(
    String streamId, {
    int? limit,
    required T Function(Map<String, dynamic> doc) fromMap,
    bool Function(T value)? filter,
    Comparable Function(T value)? sortBy,
    bool reverse = true,
  }) {
    if (!connected) {
      socket.connect();
    }

    final cacheKey = _streamCacheKey(
      streamId: streamId,
      reverse: reverse,
      limit: limit,
    );

    _cachedData[cacheKey] ??= Reactive({});
    final react = _cachedData[cacheKey]!.as((cached) {
      List<T> list = [];
      final values = [...cached.values];
      values.sort(
        (a, b) =>
            reverse
                ? '${b["_id"]}'.compareTo('${a["_id"]}')
                : '${a["_id"]}'.compareTo('${b["_id"]}'),
      );
      for (final doc in values) {
        try {
          final mapped = fromMap(doc);
          list.add(mapped);
        } catch (e) {
          _log("Failed to parse ${doc["_id"]} in $streamId");
        }
      }

      final filtered = list.where((v) => filter?.call(v) ?? true).toList();

      if (sortBy != null) {
        filtered.sort(
          (a, b) =>
              reverse
                  ? sortBy(b).compareTo(sortBy(a))
                  : sortBy(a).compareTo(sortBy(b)),
        );
      }

      return filtered;
    });

    final controller = StreamController<List<T>>.broadcast();
    StreamSubscription<List<T>>? subscription;

    void startListening() {
      _ensureRealtimeStream(
        cacheKey: cacheKey,
        streamId: streamId,
        reverse: reverse,
        limit: limit,
      );
      _streamSubscribers[cacheKey] = (_streamSubscribers[cacheKey] ?? 0) + 1;
      subscription = react.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    }

    void stopListening() {
      subscription?.cancel();
      subscription = null;

      final count = (_streamSubscribers[cacheKey] ?? 1) - 1;
      if (count <= 0) {
        _streamSubscribers.remove(cacheKey);
        _disposeRealtimeStream(cacheKey);
      } else {
        _streamSubscribers[cacheKey] = count;
      }
    }

    controller
      ..onListen = startListening
      ..onCancel = stopListening;

    return controller.stream;
  }

  /// Creates and registers a new [RealtimeListener] for a list of [events].
  RealtimeListener _createListener({
    List<String> events = const [],
    void Function(RealtimeChange change)? callback,
  }) {
    final controller = StreamController<RealtimeChange>();
    final listener = RealtimeListener(
      events: events,
      callback: callback,
      controller: controller,
    );

    // Set up cancellation logic
    listener.cancel = () {
      _listeners.removeWhere((l) => l._id == listener._id);
      controller.close();
    };

    _listeners.add(listener);

    return listener;
  }

  /// Logs a message to the console if [_showLogs] is enabled.
  void _log(String message, [PrintType? type]) {
    if (_showLogs) {
      Printer(type).write("[REALTIME] $message");
    }
  }

  /// Builds a full event name from optional collection, document, and change type.
  ///
  /// Format: `db:<type>:<collection>:<docId>`
  String _buildEventName({
    String? collection,
    String? docId,
    RealtimeChangeType? type,
  }) {
    String ev = "db:";
    ev += type == null ? "change" : type.name;
    if (collection != null) ev += ":$collection";
    if (docId != null) ev += ":$docId";

    return ev;
  }

  /// Replaces the auth token used for future socket connections, then reconnects.
  void refreshAuthToken(String newToken) {
    socket.auth.token = newToken;
    reconnect();
  }

  Future<bool> _connect() async {
    socket.connect();
    await Future.delayed(Duration(milliseconds: connectionDelay));
    return socket.connected;
  }

  /// Try to connect [retries] times within each [interval]
  Future<bool> forceConnect({
    int retries = 10,
    Duration interval = const Duration(seconds: 5),
  }) async {
    _log("Connecting...");
    if (retries <= 0) retries = 1;
    for (var i = 1; i <= retries; i++) {
      if (i != 1) await Future.delayed(interval);
      if (await _connect()) {
        _log('Connected after $i attempt${i > 1 ? "s" : ""}');
        return true;
      }
    }
    socket.emitReserved(
      'connect_error',
      'Cannot connect after $retries attempt${retries > 1 ? "s" : ""}',
    );

    return false;
  }

  /// Attempts a single manual socket connection.
  ///
  /// Returns `true` when the socket reports itself as connected after
  /// [connectionDelay], otherwise emits a synthetic `connect_error` event and
  /// returns `false`.
  Future<bool> connect() async {
    _log("Connecting...");
    bool v = await _connect();
    if (!v) {
      socket.emitReserved('connect_error', 'Connection refused or aborted');
    }
    return v;
  }

  /// Forces a disconnect followed by a reconnect attempt.
  bool reconnect() {
    socket.disconnect().connect();
    return socket.connected;
  }

  String _streamCacheKey({
    required String streamId,
    required bool reverse,
    int? limit,
  }) {
    return '$streamId|reverse:$reverse|limit:${limit ?? "null"}';
  }

  void _ensureRealtimeStream({
    required String cacheKey,
    required String streamId,
    required bool reverse,
    int? limit,
  }) {
    if (_streams.containsKey(cacheKey)) {
      return;
    }

    final registerId = Uuid.long();
    final data = RealtimeStreamData(
      streamId: streamId,
      reverse: reverse,
      registerId: registerId,
      limit: limit,
    );

    void handler(dynamic map) {
      final eventData = RealtimeEventData.fromMap(map);

      Reactive.run(() {
        for (final doc in eventData.added) {
          final id = doc["_id"];
          _cachedData[cacheKey]?.put(id, doc);
        }

        for (final doc in eventData.removed) {
          final id = doc["_id"];
          _cachedData[cacheKey]?.remove(id);
        }
      });
    }

    _streams[cacheKey] = data;
    _streamHandlers[cacheKey] = handler;

    socket.on("realtime:$streamId", handler);
    socket.on("realtime:$streamId:$registerId", handler);
    socket.emit("realtime", data.toMap());
  }

  void _disposeRealtimeStream(String cacheKey) {
    final data = _streams.remove(cacheKey);
    final handler = _streamHandlers.remove(cacheKey);

    if (data == null || handler == null) {
      _cachedData.remove(cacheKey);
      return;
    }

    socket.off("realtime:${data.streamId}", handler);
    socket.off("realtime:${data.streamId}:${data.registerId}", handler);
    _cachedData.remove(cacheKey);
  }
}

MongoRealtime get kRealtime => MongoRealtime.instance;
