library;
// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';

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
  final Map<String, Map<String, Map<String, dynamic>>> _cachedData = {};
  final bool _showLogs;

  Map<String, Map<String, dynamic>> getData<T>(String coll) {
    return _cachedData[coll] ?? {};
  }

  /// Delay in milliseconds before check if connected
  final int connectionDelay;

  String get uri => socket.io.uri;
  bool get connected => socket.connected;

  static const String _minimumVersion = "2.0.2";

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
          ..enableForceNew().setExtraHeaders(headers ?? {});

    socket = io(url, optionBuilder.build());

    socket
      ..onConnect((data) {
        _log("Connected", PrintType.success);

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

  _RealtimeDB db([List<String?> collections = const []]) =>
      _RealtimeDB(this, collections);

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
  /// final stream = MongoRealtime().stream("users");
  /// stream.listen((users) {
  ///   print(users.list); // List<Map<String, dynamic>>
  /// });
  /// ```

  Stream<List<Map<String, dynamic>>> stream(
    String streamId, {
    int? limit,
    bool Function(Map<String, dynamic> doc)? filter,
    Comparable Function(Map<String, dynamic> value)? sortBy,
    bool? sortOrderDesc,
    bool? reverse,
  }) {
    return streamMapped<Map<String, dynamic>>(
      streamId,
      limit: limit,
      filter: filter,
      fromMap: (d) => d,
      sortBy: sortBy,
      reverse: reverse,
      sortOrderDesc: sortOrderDesc,
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
  /// final stream = MongoRealtime().streamMapped<User>(
  ///   "users",
  ///   fromMap: (doc) => User.fromJson(doc),
  ///   filter: (user) => user.age > 18,
  /// );
  ///
  /// stream.listen((users) {
  ///   print(users.list); // List<User> with age > 18
  /// });
  /// ```
  ///
  /// - [streamId]: Identifier of the stream (used in the socket event).
  /// - [fromMap]: A function that converts a raw document (`Map<String, dynamic>`)
  ///   into an instance of type [T].
  /// - [filter]: An optional function to include/exclude items from the list.
  /// - [sortBy]: An optional function to sort the list by an attribute.
  /// - [sortOrderDesc]: Sort in DESC order.
  /// - [reverse]: Get docs from last.
  /// - [limit]: Limit per fetch.

  Stream<List<T>> streamMapped<T>(
    String streamId, {
    int? limit,
    required T Function(Map<String, dynamic> doc) fromMap,
    bool Function(T value)? filter,
    Comparable Function(T value)? sortBy,
    bool? sortOrderDesc,
    bool? reverse,
  }) {
    if (!connected) reconnect(); // to prevent stream stop forever when offline

    StreamController<List<T>> controller = StreamController();
    final results = getData(streamId);

    List<T> filterAndSort() {
      List<T> list = [];
      for (final doc in results.values) {
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
              sortOrderDesc ?? false
                  ? sortBy(b).compareTo(sortBy(a))
                  : sortBy(a).compareTo(sortBy(b)),
        );
      }

      return filtered;
    }

    if (results.keys.isNotEmpty) {
      controller.add(filterAndSort()); // send if has in cache
    }

    final registerId = Uuid.long();

    socket.emit("realtime", {
      "streamId": streamId,
      "limit": limit,
      "reverse": reverse ?? true,
      "registerId": registerId,
    });

    handler(map) {
      final data = RealtimeEventData.fromMap(map);
      _cachedData[streamId] ??= {};

      for (final doc in data.added) {
        final id = doc["_id"];
        results[id] = doc;
        _cachedData[streamId]![id] = doc;
      }

      for (final doc in data.removed) {
        final id = doc["_id"];
        results.remove(id);
        _cachedData[streamId]?.remove(id);
      }

      controller.add(filterAndSort());
    }

    socket.on("realtime:$streamId", handler);
    socket.on("realtime:$streamId:$registerId", handler);

    return controller.stream.asBroadcastStream();
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

  /// Connect manually the socket
  Future<bool> connect() async {
    _log("Connecting...");
    bool v = await _connect();
    if (!v) {
      socket.emitReserved('connect_error', 'Connection refused or aborted');
    }
    return v;
  }

  /// Reconnect the socket after disconnecting it.
  bool reconnect() {
    socket.disconnect().connect();
    return socket.connected;
  }
}

MongoRealtime get kRealtime => MongoRealtime.instance;
