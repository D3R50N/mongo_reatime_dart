// ignore_for_file: avoid_print

import 'package:mongo_realtime/mongo_realtime.dart';
import 'package:mongo_realtime/utils/printer.dart';

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
      .streamMapped(
        "adidas",
        reverse: false,
        fromMap: (Map<String, dynamic> doc) {
          return doc["email"] as String?;
        },
      )
      .listen((d) {
        // print(d.list.lastOrNull);
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
