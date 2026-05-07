part of '../../mongo_realtime.dart';

int compareJsonValues(Object? left, Object? right) {
  if (identical(left, right)) {
    return 0;
  }
  if (left == null) {
    return -1;
  }
  if (right == null) {
    return 1;
  }
  if (left is num && right is num) {
    return left.compareTo(right);
  }
  if (left is String && right is String) {
    return left.compareTo(right);
  }
  if (left is bool && right is bool) {
    return left == right ? 0 : (left ? 1 : -1);
  }
  if (left is DateTime && right is DateTime) {
    return left.compareTo(right);
  }
  return stableJsonEncode(left).compareTo(stableJsonEncode(right));
}
