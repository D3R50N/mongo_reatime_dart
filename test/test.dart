import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init('ws://localhost:3000', token: "1234");
  realtime.forceConnect();
  realtime.listStream("usersWithName").listen((d) {
    print(d);
  });

  realtime.listStream("usersWithName").listen((d) {
    print(d);
  });

  realtime.socket.on("custom-event", (data) {});
  realtime.socket.on("db:insert:users:1234", (data) {});
}
