part of "../mongo_realtime.dart";

/// A listener that reacts to MongoDB change events.
///
/// Each listener has a unique [_id], a list of [events] it listens to,
/// and optionally a [_callback] and a [stream] to emit changes.
class RealtimeListener {
  /// Unique identifier for the listener (generated with `Uuid.long`).
  final String _id = Uuid.long(3, 12);

  /// List of event names this listener is interested in.
  final List<String> _events;

  /// Optional callback function invoked when a matching change is received.
  final void Function(RealtimeChange change)? _callback;

  /// Optional function to remove/unsubscribe this listener.
  void Function() cancel = () {};

  final StreamController<RealtimeChange> _controller;

  /// Stream that emits changes received by this listener.
  Stream<RealtimeChange> get stream => _controller.stream;

  /// Creates a [RealtimeListener] instance.
  ///
  /// [_events] can be used to scope what types of changes to listen for.
  /// [callback] is triggered alongside pushing the change into the stream.
  RealtimeListener({
    List<String> events = const [],
    void Function(RealtimeChange change)? callback,
    required StreamController<RealtimeChange> controller,
  }) : _controller = controller,
       _events = events,
       _callback = callback;

  /// Emits a [RealtimeChange] to the stream and invokes the callback if defined.
  void call(RealtimeChange change) {
    _controller.add(change);
    if (_callback != null) _callback(change);
  }

  @override
  String toString() => 'RealtimeListener(id: $_id, events: $_events)';
}
