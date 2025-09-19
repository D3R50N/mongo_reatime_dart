// ignore_for_file: avoid_print
/// Types of messages that can be printed with color styling.
enum PrintType { warning, success, error }

/// A simple colored console printer based on the message type.
/// Uses ANSI escape codes for color output.
class Printer {
  final PrintType? _type;

  /// Creates a [Printer] instance with an optional [PrintType].
  /// If no type is provided, the message is printed with no color.
  Printer([PrintType? type]) : _type = type;

  void clear() {
    print('\x1B[2J\x1B[0;0H');
  }

  /// Writes [text] to the console using the color based on [_type].
  void write(String text) {
    switch (_type) {
      case PrintType.success:
        _printSuccess(text);
        break;
      case PrintType.error:
        _printError(text);
        break;
      case PrintType.warning:
        _printWarning(text);
        break;
      default:
        _printText(text);
    }
  }

  /// Prints plain [text] without any color.
  void _printText(String text) {
    print(text);
  }

  /// Prints [text] to the console as a warning message (yellow).
  void _printWarning(String text) {
    print('\x1B[33m$text\x1B[0m');
  }

  /// Prints [text] to the console as a success message (green).
  void _printSuccess(String text) {
    print('\x1B[32m$text\x1B[0m');
  }

  /// Prints [text] to the console as an error message (red).
  void _printError(String text) {
    print('\x1B[31m$text\x1B[0m');
  }
}
