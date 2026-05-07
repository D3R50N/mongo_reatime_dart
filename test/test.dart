import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.connect('ws://rc-test.onrender.com', authData: "1234");
  final users = realtime.collection("users");

  users.stream.listen((d) {
    print(d.length);
  });

  print(
    users
        .where('name', matches: 'admin')
        .or((q) {
          q.where('age', isGreaterThan: 18);
          q.where('status', isEqualTo: 'active');
        })
        .or((q) {
          q.where('teeth', isLessOrEqualTo: 32);
          q.where('teeth', isEqualTo: 40);
        })
        .definition
        .filter,
  );

  print(
    users
        .or((q) {
          q.where('age', isGreaterThan: 18);
          q.where('status', isEqualTo: 'active');
        })
        .definition
        .filter,
  );
  users
      .where('name', matches: 'admin')
      .or((q) {
        q.where('age', isGreaterThan: 18);
        q.where('status', isEqualTo: 'active');
      })
      .stream
      .listen((d) {
        if (d.isNotEmpty) print(d.first.data['name']);
      });
}
