// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../mongo_realtime.dart';

enum RealtimeDbChangeType { insert, update, delete, change }

class RealtimeDbChange {
  final RealtimeDbChangeType type;
  final String collection;
  final String docId;
  final JsonMap? fullDocument;

  T cast<T>(T Function(JsonMap documentId) fromJson) {
    if (fullDocument == null) {
      throw StateError('No full document available for this change.');
    }
    return fromJson(fullDocument!);
  }

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
