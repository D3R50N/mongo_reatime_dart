import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init('ws://localhost:3000', token: "1234");
  kRealtime.forceConnect();
  kRealtime.stream("usersWithName").listen((d) {
    print(d);
  });

  kRealtime.socket.on("custom-event", (data) {});
  kRealtime.socket.on("db:insert:users:1234", (data) {});
}
