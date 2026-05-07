part of '../../mongo_realtime.dart';

/// Types of messages that can be printed with color styling.
enum _PrintType { warning, success, error }

/// A simple colored console printer based on the message type.
/// Uses ANSI escape codes for color output.
class _Printer {
  final _PrintType? _type;

  /// Creates a [_Printer] instance with an optional [_PrintType].
  /// If no type is provided, the message is printed with no color.
  _Printer([_PrintType? type]) : _type = type;

  static void _print(String text) {
    developer.log(text, level: 300, name: 'MongoRealtime');
  }

  // static void _clear() {
  //   _print('\x1B[2J\x1B[0;0H');
  // }

  /// Writes [text] to the console using the color based on [_type].
  void write(String text) {
    switch (_type) {
      case _PrintType.success:
        _printSuccess(text);
        break;
      case _PrintType.error:
        _printError(text);
        break;
      case _PrintType.warning:
        _printWarning(text);
        break;
      default:
        _printText(text);
    }
  }

  /// Prints plain [text] without any color.
  static void _printText(String text) {
    _print("\x1B[37m$text\x1B[0m");
  }

  /// Prints [text] to the console as a warning message (yellow).
  static void _printWarning(String text) {
    _print('\x1B[33m$text\x1B[0m');
  }

  /// Prints [text] to the console as a success message (green).
  static void _printSuccess(String text) {
    _print('\x1B[32m$text\x1B[0m');
  }

  /// Prints [text] to the console as an error message (red).
  static void _printError(String text) {
    _print('\x1B[31m$text\x1B[0m');
  }
}
