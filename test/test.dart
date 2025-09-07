import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init(
    'ws://192.168.48.8:41366',
    autoConnect: true,
    onConnectError: (data) {
      print("oups");
    },
    onConnect: (data) {
      print('Connected');
    },
    onError: (error) {
      print(error);
    },
    onDisconnect: (reason) {
      print('Reason $reason');
    },
  );

  realtime.socket.on("custom-event", (data) {});
  realtime.socket.on("db:insert:users:1234", (data) {});

  await Future.delayed(Duration(seconds: 2));
  realtime.connect();
  await Future.delayed(Duration(seconds: 2));
  realtime.connect();
  await Future.delayed(Duration(seconds: 10));

  realtime.reconnect();
}
