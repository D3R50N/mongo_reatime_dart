import 'package:mongo_realtime/mongo_realtime.dart';

void _print(dynamic t, [String? message]) {
  print('${message != null ? '[$message] ' : ''}$t');
}

void main() async {
  MongoRealtime.connect('localhost:3000', authData: "ok");
  final users = realtime.collection("users");

  users.where('age', isLowerThan: 10).stream.listen((d) {
    _print(d.length, '<10');
  });
  users.where('age', isGreaterOrEqualTo: 5).stream.listen((d) {
    _print(d.length, '>=5');
  });

  inc() async {
    await Future.delayed(Duration(seconds: 2));
    await users
        .where('firstname', matches: RegExp('max', caseSensitive: false))
        .update($inc: {'age': 10});
    await inc();
  }

  inc();
}
