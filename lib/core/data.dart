/// Data from realtime stream
class RealtimeData<T> {
  /// List of data from stream
  final List<T> list;

  /// Collection attached to the stream
  final String coll;

  /// Count of docs in the collection
  final int totalCount;

  /// NUmber of docs remainings to complete the stream
  final int remaining;

  RealtimeData({
    required this.list,
    required this.coll,
    required this.totalCount,
    required this.remaining,
  });

  /// Count of the list (same as list.length)
  int get count => list.length;
}
