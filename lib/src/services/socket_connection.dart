part of '../../mongo_realtime.dart';

class RealtimeSocketConnection {
  RealtimeSocketConnection._(this._channel);

  factory RealtimeSocketConnection.connect(Uri uri, [Object? authData]) {
    String? authDataEncode;
    if (authData != null) {
      if (authData is Map) {
        authDataEncode = jsonEncode(authData);
      } else if (authData is Iterable) {
        authDataEncode = jsonEncode({
          for (var i = 0; i < authData.length; i++) '$i': authData.elementAt(i),
        });
      } else {
        authDataEncode = authData.toString();
      }
    }
    return RealtimeSocketConnection._(IOWebSocketChannel.connect(
      uri,
      headers: {if (authDataEncode != null) 'auth': authDataEncode},
    ));
  }

  final WebSocketChannel _channel;

  Stream<dynamic> get stream => _channel.stream;

  Future<void> add(String message) async {
    _channel.sink.add(message);
  }

  Future<void> close([int? code, String? reason]) async {
    await _channel.sink.close(code, reason);
  }
}
