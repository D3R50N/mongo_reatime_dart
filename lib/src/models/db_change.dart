// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../mongo_realtime.dart';

/// Types of database changes that can be reported to watchers.
enum RealtimeDbChangeType { insert, update, delete, change }

/// Represents a database change event received from the realtime server.
class RealtimeDbChange {
  final RealtimeDbChangeType type;
  final String collection;
  final String docId;
  final JsonMap? fullDocument;

  /// Casts the full document payload to a typed object using [fromJson].
  ///
  /// Throws if the full document is not present.
  T cast<T>(T Function(JsonMap documentId) fromJson) {
    if (fullDocument == null) {
      throw StateError('No full document available for this change.');
    }
    return fromJson(fullDocument!);
  }

  /// Attempts to cast the full document payload to a typed object.
  ///
  /// Returns null if the full document is not present or conversion fails.
  T? tryCast<T>(T Function(JsonMap doc) fromJson) {
    if (fullDocument == null) {
      return null;
    }
    try {
      return fromJson(fullDocument!);
    } catch (_) {
      return null;
    }
  }

  bool get isInsert => type == RealtimeDbChangeType.insert;
  bool get isUpdate => type == RealtimeDbChangeType.update;
  bool get isDelete => type == RealtimeDbChangeType.delete;
  bool get isChange => type == RealtimeDbChangeType.change;

  RealtimeDbChange({
    required this.type,
    required this.collection,
    required this.docId,
    this.fullDocument,
  });

  factory RealtimeDbChange.fromJson(JsonMap json) {
    final typeStr = json['operationType']?.toString();
    final type = switch (typeStr) {
      'insert' => RealtimeDbChangeType.insert,
      'update' => RealtimeDbChangeType.update,
      'delete' => RealtimeDbChangeType.delete,
      _ => RealtimeDbChangeType.change,
    };

    return RealtimeDbChange(
      type: type,
      collection: json['collection']!.toString(),
      docId: json['docId']!.toString(),
      fullDocument: json['fullDocument'] as JsonMap?,
    );
  }

  @override
  String toString() {
    return 'RealtimeDbChange(type: $type, collection: $collection, docId: $docId)';
  }
}
