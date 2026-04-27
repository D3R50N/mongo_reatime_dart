import 'package:flutter/material.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

/// A Flutter widget that rebuilds from a realtime collection stream.
///
/// Use [fromMap] to map incoming Mongo documents to a typed model, or omit it
/// to receive raw `Map<String, dynamic>` values through [child].
class RealtimeBuilder<T> extends StatefulWidget {
  const RealtimeBuilder({
    super.key,
    this.instance,
    required this.stream,
    this.limit,
    this.fromMap,
    this.filter,
    this.sortBy,
    this.reverse = true,
    this.errorBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    required this.child,
  });

  final MongoRealtime? instance;
  final String stream;
  final int? limit;
  final T Function(Map<String, dynamic> doc)? fromMap;
  final bool Function(T value)? filter;
  final Comparable Function(T value)? sortBy;
  final bool reverse;

  final Widget Function(Object? error)? errorBuilder;
  final Widget Function()? loadingBuilder;
  final Widget Function()? emptyBuilder;
  final Widget Function(List<T> list) child;

  @override
  State<RealtimeBuilder> createState() => _RealtimeBuilderState();
}

class _RealtimeBuilderState extends State<RealtimeBuilder> {
  late MongoRealtime mr = widget.instance ?? MongoRealtime.instance;

  late Stream<List<dynamic>> realtimeStream = _createStream();

  Stream<List<dynamic>> _createStream() {
    final fromMap = widget.fromMap;
    final filter = widget.filter;
    final limit = widget.limit;
    final reverse = widget.reverse;
    final sortBy = widget.sortBy;
    final streamId = widget.stream;

    return fromMap != null
        ? mr.streamMapped(
          streamId,
          fromMap: fromMap,
          filter: filter,
          limit: limit,
          reverse: reverse,
          sortBy: sortBy,
        )
        : mr.stream(
          streamId,
          filter: filter,
          limit: limit,
          reverse: reverse,
          sortBy: sortBy,
        );
  }

  @override
  void didUpdateWidget(covariant RealtimeBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextMr = widget.instance ?? MongoRealtime.instance;
    final shouldRefresh =
        oldWidget.instance != widget.instance ||
        oldWidget.stream != widget.stream ||
        oldWidget.limit != widget.limit ||
        oldWidget.fromMap != widget.fromMap ||
        oldWidget.filter != widget.filter ||
        oldWidget.sortBy != widget.sortBy ||
        oldWidget.reverse != widget.reverse;

    if (shouldRefresh) {
      mr = nextMr;
      realtimeStream = _createStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: realtimeStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final defaultEmpty = SizedBox.shrink();
        if (snapshot.hasError) {
          return widget.errorBuilder?.call(snapshot.error) ?? defaultEmpty;
        }
        if (data == null) {
          return widget.loadingBuilder?.call() ?? defaultEmpty;
        }
        if (data.isEmpty && widget.emptyBuilder != null) {
          return widget.emptyBuilder!();
        }

        return widget.child(data);
      },
    );
  }
}
