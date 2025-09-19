import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init('ws://localhost:3000');
  realtime.forceConnect();
  realtime.socket.on("custom-event", (data) {});
  realtime.socket.on("db:insert:users:1234", (data) {});
}
