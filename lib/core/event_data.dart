// ignore_for_file: public_member_api_docs, sort_constructors_first

part of '../mongo_realtime.dart';

/// Parsed event got from server
class RealtimeEventData {
  final List<Map<String, dynamic>> results;
  final String coll;
  final int count;
  final int total;
  final int remaining;

  RealtimeEventData({
    required this.results,
    required this.coll,
    required this.count,
    required this.total,
    required this.remaining,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'results': results,
      'coll': coll,
      'count': count,
      'total': total,
      'remaining': remaining,
    };
  }

  factory RealtimeEventData.fromMap(Map<String, dynamic> map) {
    return RealtimeEventData(
      results: List<Map<String, dynamic>>.from(map['results']),
      coll: map['coll'] as String,
      count: map['count'] as int,
      total: map['total'] as int,
      remaining: map['remaining'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory RealtimeEventData.fromJson(String source) =>
      RealtimeEventData.fromMap(json.decode(source) as Map<String, dynamic>);
}
