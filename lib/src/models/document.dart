part of '../../mongo_realtime.dart';

class RealtimeDocument<T> {
  RealtimeDocument._({
    required this.id,
    required JsonMap data,
    this.value,
  }) : data = Map.unmodifiable(data);

  factory RealtimeDocument.fromJson(
    JsonMap json, {
    FromJson<T>? fromJson,
  }) {
    final copied = deepCopyMap(json);
    final id = (copied['_id'] ?? '').toString();

    T? value;
    if (fromJson != null) {
      value = fromJson(deepCopyMap(copied));
    } else {
      try {
        value = copied as T;
      } on Object {
        value = null;
      }
    }

    return RealtimeDocument._(
      id: id,
      data: copied,
      value: value,
    );
  }

  final String id;
  final JsonMap data;
  final T? value;

  @override
  bool operator ==(Object other) {
    return other is RealtimeDocument<T> &&
        other.id == id &&
        deepEquals(other.data, data) &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(id, stableJsonEncode(data), value);

  @override
  String toString() =>
      'RealtimeDocument<$T>(id: $id, data: $data, value: $value)';
}
