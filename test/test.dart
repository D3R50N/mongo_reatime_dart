import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.connect('http://frisz-api-dev.onrender.com/', authData: "1234");
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

  users
      .where('name', matches: 'admin')
      .or((q) {
        q.where('age', isGreaterThan: 18);
        q.where('status', isEqualTo: 'active');
      })
      .stream
      .listen((d) {
        print(d.length);
      });
}
