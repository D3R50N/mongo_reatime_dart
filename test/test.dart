import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init(
    'ws://localhost:3000',
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
}
