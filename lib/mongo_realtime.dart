// ignore_for_file: public_member_api_docs, sort_constructors_first
// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:mongo_realtime/core/uuid.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'core/printer.dart';

export 'core/uuid.dart';

/// Enum representing the possible types of MongoDB change events.
enum MongoChangeType { insert, update, delete, replace, invalidate, drop }

class _MongoChange {
  /// The operation type as a string (e.g. "insert", "update", etc.)
  final String operationType;

  /// The collection where the change occurred.
  final String collection;

  /// The ID of the affected document.
  final String documentId;

  /// The full document after the change (only present in some change types).
  final Map<String, dynamic>? doc;

  /// Details about the fields that were updated or removed (for updates).
  final Map<String, dynamic>? updateDescription;

  /// The raw payload of the change event.
  final Map<String, dynamic> raw;

  /// The typed version of the operationType string.
  MongoChangeType get type =>
      MongoChangeType.values.firstWhere((v) => v.name == operationType);

  _MongoChange({
    required this.operationType,
    required this.collection,
    required this.documentId,
    this.doc,
    this.updateDescription,
    required this.raw,
  });

  /// Creates a [_MongoChange] instance from a raw JSON change payload.
  ///
  /// Tries to extract the collection and document ID from either:
  /// - `col`
  /// - `ns.coll`
  /// - `documentKey._id`
  ///
  /// Handles optional presence of `fullDocument` and `updateDescription`.
  factory _MongoChange.fromJson(Map<String, dynamic> json) {
    return _MongoChange(
      operationType: json['operationType'] ?? "update",
      collection: json['col'] ?? json['ns']?['coll'] ?? '',
      documentId:
          json['docId'] ?? json['documentKey']?['_id']?.toString() ?? '',
      doc:
          json['fullDocument'] != null
              ? Map<String, dynamic>.from(json['fullDocument'])
              : null,
      updateDescription:
          json['updateDescription'] != null
              ? Map<String, dynamic>.from(json['updateDescription'])
              : null,
      raw: json,
    );
  }

  /// Whether this change event is an `insert`.
  bool get isInsert => type == MongoChangeType.insert;

  /// Whether this change event is an `update`.
  bool get isUpdate => type == MongoChangeType.update;

  /// Whether this change event is a `delete`.
  bool get isDelete => type == MongoChangeType.delete;

  /// Whether this change event is a `replace`.
  bool get isReplace => type == MongoChangeType.replace;

  /// Whether this change event is an `invalidate` (e.g. stream invalidated).
  bool get isInvalidate => type == MongoChangeType.invalidate;

  /// Whether this change event is a `drop` (e.g. collection dropped).
  bool get isDrop => type == MongoChangeType.drop;

  /// Fields that were updated (only for update events).
  Map<String, dynamic>? get updatedFields =>
      updateDescription?['updatedFields'] as Map<String, dynamic>?;

  /// Fields that were removed (only for update events).
  List<String>? get removedFields =>
      (updateDescription?['removedFields'] as List?)?.cast<String>();

  @override
  String toString() {
    return '_MongoChange(type: $operationType, col: $collection, docId: $documentId)';
  }
}

/// A listener that reacts to MongoDB change events.
///
/// Each listener has a unique [_id], a list of [events] it listens to,
/// and optionally a [_callback] and a [stream] to emit changes.
class _MongoListener {
  /// Unique identifier for the listener (generated with `Uuid.long`).
  final String _id = Uuid.long(3, 12);

  /// List of event names this listener is interested in.
  final List<String> _events;

  /// Optional callback function invoked when a matching change is received.
  final void Function(_MongoChange change)? _callback;

  /// Optional function to remove/unsubscribe this listener.
  void Function() cancel = () {};

  final StreamController<_MongoChange> _controller;

  /// Stream that emits changes received by this listener.
  Stream<_MongoChange> get stream => _controller.stream;

  /// Creates a [_MongoListener] instance.
  ///
  /// [_events] can be used to scope what types of changes to listen for.
  /// [callback] is triggered alongside pushing the change into the stream.
  _MongoListener({
    List<String> events = const [],
    void Function(_MongoChange change)? callback,
    required StreamController<_MongoChange> controller,
  }) : _controller = controller,
       _events = events,
       _callback = callback;

  /// Emits a [_MongoChange] to the stream and invokes the callback if defined.
  void call(_MongoChange change) {
    _controller.add(change);
    if (_callback != null) _callback(change);
  }

  @override
  String toString() => '_MongoListener(id: $_id, events: $_events)';
}

/// A singleton-like service that connects to a backend via WebSocket
/// and dispatches MongoDB change events to listeners based on event names.
class MongoRealtime {
  static late MongoRealtime instance;

  late final Socket socket;
  final List<_MongoListener> _listeners = [];
  final Map<String, String> _registeredStreams = {};
  final Map<String, List<dynamic>> _cachedStreams = {};
  final bool _showLogs;

  /// Delay in milliseconds before check if connected
  final int connectionDelay;

  String get uri => socket.io.uri;
  bool get connected => socket.connected;

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
      ..onReconnect((_) {
        for (final e in _registeredStreams.entries) {
          final streamId = e.value;
          final registerId = e.key;
          _registerListStream(streamId, registerId);
        }
      })
      ..onAny((event, data) {
        if (!event.startsWith('db:')) return;
        // _log("Received '$event'");
        for (final listener in _listeners.where(
          (l) => l._events.contains(event),
        )) {
          final change = _MongoChange.fromJson(data);
          listener.call(change);
        }
      });

    if (autoConnect) connect();
  }

  _MongoRealtimeDB db([List<String?> collections = const []]) =>
      _MongoRealtimeDB(this, collections);

  _MongoRealtimeCol col(String collection) =>
      _MongoRealtimeCol(this, collection);

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
  /// This is a convenience wrapper around [listStreamMapped] when no mapping is
  /// needed and the documents should be used as-is.
  ///
  /// Example:
  /// ```dart
  /// final stream = MongoRealtime().listStream("users");
  /// stream.listen((users) {
  ///   print(users); // List<Map<String, dynamic>>
  /// });
  /// ```
  Stream<List<Map<String, dynamic>>> listStream(
    String streamId, {
    bool Function(Map<String, dynamic> doc)? filter,
  }) {
    return listStreamMapped<Map<String, dynamic>>(
      streamId,
      filter: filter,
      fromMap: (d) => d,
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
  /// final stream = MongoRealtime().listStreamMapped<User>(
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
  Stream<List<T>> listStreamMapped<T>(
    String streamId, {
    required T Function(Map<String, dynamic> doc) fromMap,
    bool Function(T value)? filter,
  }) {
    StreamController<List<T>> controller = StreamController();
    
    final cached = _cachedStreams[streamId];
    if (cached != null && cached is List<T>) controller.add(cached);

    void handler(d) {
      List<T> list =
          (d as List)
              .map((e) => fromMap(e as Map<String, dynamic>))
              .where((v) => filter?.call(v) ?? true)
              .toList();

      _cachedStreams[streamId] = list;
      controller.add(list);
    }

    socket.on("db:stream:$streamId", handler);

    final registerId = Uuid.long(10); // large uuid
    socket.on("db:stream[register][$registerId]", handler);
    _registerListStream(streamId, registerId);

    return controller.stream.asBroadcastStream();
  }

  void _registerListStream(String streamId, String registerId) {
    socket.emit("db:stream[register]", [streamId, registerId]);
    if (_registeredStreams[registerId] != streamId) {
      _registeredStreams[registerId] = streamId;
    }
  }

  /// Creates and registers a new [_MongoListener] for a list of [events].
  _MongoListener _createListener({
    List<String> events = const [],
    void Function(_MongoChange change)? callback,
  }) {
    final controller = StreamController<_MongoChange>();
    final listener = _MongoListener(
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
    for (var i = 0; i < retries; i++) {
      if (i != 0) await Future.delayed(interval);
      if (await _connect()) {
        _log('Connected after $retries attempt${retries > 1 ? "s" : ""}');
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
      socket.emitReserved('connect_error', 'Cannot connect');
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

/// A listener instance to database or specific collections
class _MongoRealtimeDB {
  final List<String?> _collections;
  final MongoRealtime _mongoRealtime;

  _MongoRealtimeDB(this._mongoRealtime, List<String?> collections)
    : _collections = collections.where((t) => t != null).toList() {
    if (_collections.isEmpty) _collections.add(null);
  }

  _MongoRealtimeCol col(String collection) =>
      _MongoRealtimeCol(_mongoRealtime, collection);

  _MongoListener onChange({
    List<MongoChangeType?> types = const [],
    void Function(_MongoChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (final collection in _collections) {
      for (var type in types) {
        events.add(
          _mongoRealtime._buildEventName(collection: collection, type: type),
        );
      }
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }
}

/// A listener instance to a specific collection
class _MongoRealtimeCol {
  final String _collection;
  final MongoRealtime _mongoRealtime;

  _MongoRealtimeCol(this._mongoRealtime, String collection)
    : _collection = collection;

  _MongoRealtimeDoc doc(String docId) =>
      _MongoRealtimeDoc(_mongoRealtime, _collection, docId);

  _MongoListener onChange({
    List<MongoChangeType?> types = const [],
    void Function(_MongoChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (var type in types) {
      events.add(
        _mongoRealtime._buildEventName(collection: _collection, type: type),
      );
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }
}

/// A listener instance to a specific documet
class _MongoRealtimeDoc {
  final String _collection;
  final String _docId;
  final MongoRealtime _mongoRealtime;

  _MongoRealtimeDoc(this._mongoRealtime, String collection, String docId)
    : _collection = collection,
      _docId = docId;

  _MongoListener onChange({
    List<MongoChangeType?> types = const [],
    void Function(_MongoChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (var type in types) {
      events.add(
        _mongoRealtime._buildEventName(
          collection: _collection,
          type: type,
          docId: _docId,
        ),
      );
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }
}
