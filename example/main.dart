// ignore_for_file: avoid_print

import 'package:mongo_realtime/core/printer.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  Printer().clear();

  MongoRealtime.init(
    'ws://localhost:3000',
    autoConnect: true,
    token: "1234",
    showLogs: false,
    onConnectError: (data) {},
    onConnect: (data) {},
    onError: (error) {},
    onDisconnect: (reason) {},
  );

  kRealtime
      .listStream(
        "users",
        filter: (doc) => doc["name"] != null,
        sortBy: (value) => value["name"],
        sortOrderDesc: true,
      )
      .listen((d) {
        print(d);
      });

  kRealtime.db().onChange(types: [MongoChangeType.delete]).stream.listen((c) {
    print("Deletion detected");
  });

  kRealtime
      .col("users")
      .onChange(
        types: [MongoChangeType.insert],
        callback: (change) {
          print("New user ${change.doc?["email"]}");
        },
      );

  kRealtime.socket.on("db:insert:users:1234", (data) {});
}
