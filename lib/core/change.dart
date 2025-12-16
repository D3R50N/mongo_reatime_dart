part of "../mongo_realtime.dart";

/// Enum representing the possible types of MongoDB change events.
enum RealtimeChangeType { insert, update, delete, replace, invalidate, drop }

class RealtimeChange {
  /// The operation type as a string (e.g. "insert", "update", etc.)
  final String operationType;

  /// The collection where the change occurred.
  final String collection;

  /// The ID of the affected document.
  final String documentId;

  /// The full document after the change (only present in some change types).
  final Map<String, dynamic>? doc;

  /// Details about the fields that were updated or removed (for updates).
  final Map<String, dynamic>? updateDescription;

  /// The raw payload of the change event.
  final Map<String, dynamic> raw;

  /// The typed version of the operationType string.
  RealtimeChangeType get type =>
      RealtimeChangeType.values.firstWhere((v) => v.name == operationType);

  RealtimeChange({
    required this.operationType,
    required this.collection,
    required this.documentId,
    this.doc,
    this.updateDescription,
    required this.raw,
  });

  /// Creates a [RealtimeChange] instance from a raw JSON change payload.
  ///
  /// Tries to extract the collection and document ID from either:
  /// - `col`
  /// - `ns.coll`
  /// - `documentKey._id`
  ///
  /// Handles optional presence of `fullDocument` and `updateDescription`.
  factory RealtimeChange.fromJson(Map<String, dynamic> json) {
    return RealtimeChange(
      operationType: json['operationType'] ?? "update",
      collection: json['col'] ?? json['ns']?['coll'] ?? '',
      documentId:
          json['docId'] ?? json['documentKey']?['_id']?.toString() ?? '',
      doc:
          json['fullDocument'] != null
              ? Map<String, dynamic>.from(json['fullDocument'])
              : null,
      updateDescription:
          json['updateDescription'] != null
              ? Map<String, dynamic>.from(json['updateDescription'])
              : null,
      raw: json,
    );
  }

  /// Whether this change event is an `insert`.
  bool get isInsert => type == RealtimeChangeType.insert;

  /// Whether this change event is an `update`.
  bool get isUpdate => type == RealtimeChangeType.update;

  /// Whether this change event is a `delete`.
  bool get isDelete => type == RealtimeChangeType.delete;

  /// Whether this change event is a `replace`.
  bool get isReplace => type == RealtimeChangeType.replace;

  /// Whether this change event is an `invalidate` (e.g. stream invalidated).
  bool get isInvalidate => type == RealtimeChangeType.invalidate;

  /// Whether this change event is a `drop` (e.g. collection dropped).
  bool get isDrop => type == RealtimeChangeType.drop;

  /// Fields that were updated (only for update events).
  Map<String, dynamic>? get updatedFields =>
      updateDescription?['updatedFields'] as Map<String, dynamic>?;

  /// Fields that were removed (only for update events).
  List<String>? get removedFields =>
      (updateDescription?['removedFields'] as List?)?.cast<String>();

  @override
  String toString() {
    return 'RealtimeChange(type: $operationType, col: $collection, docId: $documentId)';
  }
}
