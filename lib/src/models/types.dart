part of '../../mongo_realtime.dart';

typedef JsonMap = Map<String, dynamic>;
typedef FromJson<T> = T Function(JsonMap json);
typedef WarningHandler = void Function(String message);
typedef ChangeHandler = void Function(RealtimeDbChange change);
