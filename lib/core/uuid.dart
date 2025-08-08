import 'dart:math';

/// Utility class to generate short and long random IDs.
abstract class Uuid {
  static final _lower = "abcdefghijklmnopqrstuvwxyz";
  static final _upper = _lower.toUpperCase();
  static final _digits = "0123456789_";

  /// Characters used for generating IDs: a-z, A-Z, 0-9 and underscore.
  static String get _chars => _lower + _upper + _digits;

  /// Generates a short random ID of [charsCount] characters (default: 6).
  static String short([int charsCount = 6]) {
    String v = "";
    for (var i = 0; i < charsCount; i++) {
      v += _chars[Random.secure().nextInt(_chars.length)];
    }
    return v;
  }

  /// Generates a longer ID by joining multiple `short()` parts with dashes.
  ///
  /// Example: `ABc12X-9YkWqE-TmN82z`
  static String long([int partsCount = 3, int charsCount = 6]) {
    List<String> v = [];
    for (var i = 0; i < partsCount; i++) {
      v.add(short(charsCount));
    }
    return v.join("-");
  }
}
