// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:async';

import 'package:mongo_realtime/core/uuid.dart';
import 'package:mongo_realtime/mongo_change.dart';

/// A listener that reacts to MongoDB change events.
///
/// Each listener has a unique [id], a list of [events] it listens to,
/// and optionally a [_callback] and a [stream] to emit changes.
class MongoListener {
  /// Unique identifier for the listener (generated with `Uuid.long`).
  final String id = Uuid.long(3, 12);

  /// List of event names this listener is interested in.
  final List<String> events;

  /// Optional callback function invoked when a matching change is received.
  final void Function(MongoChange change)? _callback;

  /// Optional function to remove/unsubscribe this listener.
  void Function() cancel = () {};

  final StreamController<MongoChange> _controller;

  /// Stream that emits changes received by this listener.
  Stream<MongoChange> get stream => _controller.stream;

  /// Creates a [MongoListener] instance.
  ///
  /// [events] can be used to scope what types of changes to listen for.
  /// [callback] is triggered alongside pushing the change into the stream.
  MongoListener({
    this.events = const [],
    void Function(MongoChange change)? callback,
    required StreamController<MongoChange> controller,
  }) : _controller = controller,
       _callback = callback;

  /// Emits a [MongoChange] to the stream and invokes the callback if defined.
  void call(MongoChange change) {
    _controller.add(change);
    if (_callback != null) _callback(change);
  }

  @override
  String toString() => 'MongoListener(id: $id, events: $events)';
}
