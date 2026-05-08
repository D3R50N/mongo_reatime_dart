import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.connect('ws://rc-test.onrender.com', authData: "1234");
  final users = realtime.collection("users");

  users.where('age', isLowerThan: 10).stream.listen((d) {
    print(d.length);
  });
}
