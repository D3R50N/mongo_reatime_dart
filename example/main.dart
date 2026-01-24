// ignore_for_file: avoid_print

import 'package:mongo_realtime/mongo_realtime.dart';
import 'package:mongo_realtime/utils/printer.dart';

void main() async {
  Printer().clear();

  MongoRealtime.init(
    'ws://localhost:3000',
    autoConnect: true,
    token: "1234",
    showLogs: true,
    onConnectError: (data) {},
    onConnect: (data) {},
    onError: (error) {},
    onDisconnect: (reason) {},
  );

  kRealtime
      .stream(
        "posts",
        reverse: true,
        sortBy: (p) => p["datePublished"] ?? DateTime.now(),
      )
      .listen((d) {
        print("-----REVERSED ${d.first["_id"]} ${d.last["_id"]} ${d.length}");
      });

  kRealtime
      .stream(
        "posts",
        reverse: false,
        sortBy: (p) => p["datePublished"] ?? DateTime.now(),
      )
      .listen((d) {
        print("----- ${d.first["_id"]}  ${d.last["_id"]} ${d.length}");
      });

  kRealtime.stream("users", reverse: false).listen((d) {
    print(
      d
          .where((p) => p["email"] == "test@frisz.fr")
          .map((p) => "${p["firstname"]} ${p["lastname"]}"),
    );
    print("-----");
  });

  kRealtime.db().onChange(types: [RealtimeChangeType.delete]).stream.listen((
    c,
  ) {
    print("Deletion detected");
  });

  kRealtime
      .col("brands")
      .doc("6941da4b75f0338f9eccb93d")
      .onChange(
        types: [RealtimeChangeType.delete],
        callback: (change) {
          print("change $change");
        },
      );
}
