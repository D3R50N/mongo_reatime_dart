import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.connect('ws://localhost:3000', authData: "1234");
  final users = realtime.collection("users");

  users.stream.listen((d) {
    print(d);
  });

  users
      .where('name', matches: 'admin')
      .or((q) {
        q.where('age', isGreaterThan: 18);
        q.where('status', isEqualTo: 'active');
      })
      .stream
      .listen((d) {
        print(d);
      });
}
