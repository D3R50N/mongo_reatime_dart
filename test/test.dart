import 'package:mongo_realtime/mongo_realtime.dart';

void _print(dynamic t, [String? message]) {
  print('${message != null ? '[$message] ' : ''}$t');
}

void main() async {
  MongoRealtime.connect('http://localhost:3000/ws', authData: "ok");
  final users = realtime.collection("users", fromJson: (json) => json['email'].toString());

  users
      .where('age', isLowerThan: 10)
      .streamWithValue
      .listen(
        (d) {
          _print(d, '<10');
        },
        onError: (e) {
          _print(e, 'error');
        },
      );
  users
      .where('age', isGreaterOrEqualTo: 5)
      .streamWithValue
      .listen(
        (d) {
          _print(d, '>=5');
        },
        onError: (e) {
          _print(e, 'error');
        },
      );
  users
      .where('firstname', isEqualTo: 'Max')
      .streamWithValue
      .listen(
        (d) {
          _print(d, 'Max');
        },
        onError: (e) {
          _print(e, 'error');
        },
      );
}
