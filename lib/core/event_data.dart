// ignore_for_file: public_member_api_docs, sort_constructors_first

part of '../mongo_realtime.dart';

/// Parsed event got from server
class RealtimeEventData {
  final List<Map<String, dynamic>> added;
  final List<Map<String, dynamic>> removed;

  RealtimeEventData({required this.added, required this.removed});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'added': added, 'removed': removed};
  }

  factory RealtimeEventData.fromMap(Map<String, dynamic> map) {
    return RealtimeEventData(
      added:
          List<Map<String, dynamic>?>.from(
            (map['added'] ?? []),
          ).nonNulls.toList(),
      removed:
          List<Map<String, dynamic>?>.from(
            (map['removed'] ?? []),
          ).nonNulls.toList(),
    );
  }

  String toJson() => json.encode(toMap());

  factory RealtimeEventData.fromJson(String source) =>
      RealtimeEventData.fromMap(json.decode(source) as Map<String, dynamic>);
}
