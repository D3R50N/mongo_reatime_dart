import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  final realtime = MongoRealtime.instance;

  realtime.socket.on("custom-event", (data) {});
  realtime.socket.on("db:insert:users:1234", (data) {});
}
