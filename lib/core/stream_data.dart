class RealtimeStreamData {
  final String streamId;
  final int? limit;
  final bool reverse;
  final String registerId;
  RealtimeStreamData({
    required this.streamId,
    this.limit,
    required this.reverse,
    required this.registerId,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'streamId': streamId,
      'limit': limit,
      'reverse': reverse,
      'registerId': registerId,
    };
  }
}
