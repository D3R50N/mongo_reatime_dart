import 'package:mongo_realtime/mongo_realtime.dart';

void _print(dynamic t, [String? message]) {
  print('${message != null ? '[$message] ' : ''}$t');
}

void main() async {
  try {
    MongoRealtime.connect('http://localhost:3000/ws', authData: "ok");
    final users = realtime.collection("users");

    users
        .where('age', isLowerThan: 10)
        .stream
        .listen(
          (d) {
            _print(d.length, '<10');
          },
          onError: (e) {
            _print(e, 'error');
          },
        );
    users
        .where('age', isGreaterOrEqualTo: 5)
        .stream
        .listen(
          (d) {
            _print(d.length, '>=5');
          },
          onError: (e) {
            _print(e, 'error');
          },
        );
    users
        .where('firstname', isEqualTo: 'Max')
        .stream
        .listen(
          (d) {
            _print(d.length, 'Max');
          },
          onError: (e) {
            _print(e, 'error');
          },
        );
    await Future.delayed(Duration(seconds: 2));
  } on Exception catch (_) {
    _print('add');
  }
}
