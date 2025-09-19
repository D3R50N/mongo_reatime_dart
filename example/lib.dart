// ignore_for_file: avoid_print

import 'package:mongo_realtime/core/printer.dart';
import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  Printer().clear();

  MongoRealtime.init(
    'ws://localhost:3000',
    autoConnect: true,
    token: "1234",
    onConnectError: (data) {},
    onConnect: (data) {},
    onError: (error) {},
    onDisconnect: (reason) {},
  );

  realtime
      .listStreamMapped<String>(
        "usersWithName",
        fromMap: (doc) => doc["name"],
        filter: (value) {
          return value == "Andy";
        },
      )
      .listen((s) {
        print(s);
      });

  realtime.db().onChange(types: [MongoChangeType.delete]).stream.listen((c) {
    print("Deletion detected");
  });

  realtime
      .col("users")
      .onChange(
        types: [MongoChangeType.insert],
        callback: (change) {
          print("New user ${change.doc?["email"]}");
        },
      );

  realtime.socket.on("db:insert:users:1234", (data) {});
}
