part of '../../mongo_realtime.dart';

/// A JSON-style object used throughout MongoRealtime.
typedef JsonMap = Map<String, dynamic>;

/// Converts raw document JSON into a typed object.
typedef FromJson<T> = T Function(JsonMap json);

/// Handles warning messages emitted by the MongoRealtime client.
typedef WarningHandler = void Function(String message);

/// Handles database change notifications for realtime watchers.
typedef ChangeHandler = void Function(RealtimeDbChange change);
