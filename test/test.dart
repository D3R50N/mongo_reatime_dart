import 'package:mongo_realtime/mongo_realtime.dart';

void _print(dynamic t, [String? message]) {
  print('${message != null ? '[$message] ' : ''}$t');
}

void main() async {
  MongoRealtime.connect('https://friszlink.com/', authData: "ok");
  final users = realtime.collection("users");

  users.where('age', isLowerThan: 10).stream.listen((d) {
    _print(d.length, '<10');
  });
  users.where('age', isGreaterOrEqualTo: 5).stream.listen((d) {
    _print(d.length, '>=5');
  });
  users.where('firstname', isEqualTo: 'Max').stream.listen((d) {
    _print(d.length, 'Max');
  });
}
