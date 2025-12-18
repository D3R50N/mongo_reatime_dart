import 'package:flutter/material.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

class RealtimeBuilder<T> extends StatefulWidget {
  const RealtimeBuilder({
    super.key,
    this.instance,
    required this.stream,
    this.limit,
    this.fromMap,
    this.filter,
    this.sortBy,
    this.sortOrderDesc,
    this.reverse,
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
  final bool? sortOrderDesc;
  final bool? reverse;

  final Widget Function(Object? error)? errorBuilder;
  final Widget Function()? loadingBuilder;
  final Widget Function()? emptyBuilder;
  final Widget Function(List<T> list) child;

  @override
  State<RealtimeBuilder> createState() => _RealtimeBuilderState();
}

class _RealtimeBuilderState extends State<RealtimeBuilder> {
  late MongoRealtime mr = widget.instance ?? MongoRealtime.instance;

  late final streamId = widget.stream;
  late final limit = widget.limit;
  late final fromMap = widget.fromMap;
  late final filter = widget.filter;
  late final sortBy = widget.sortBy;
  late final sortOrderDesc = widget.sortOrderDesc;
  late final reverse = widget.reverse;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream:
          fromMap != null
              ? mr.streamMapped(
                streamId,
                fromMap: fromMap!,
                filter: filter,
                limit: limit,
                reverse: reverse,
                sortBy: sortBy,
                sortOrderDesc: sortOrderDesc,
              )
              : mr.stream(
                streamId,
                filter: filter,
                limit: limit,
                reverse: reverse,
                sortBy: sortBy,
                sortOrderDesc: sortOrderDesc,
              ),
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
