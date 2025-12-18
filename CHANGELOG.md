# Changelog

## 2.0.0 (Breaking Changes)

- Stream events need a limit parameter now to avoid large data transfers.
- listStream() and listStreamMapped() methods now are named stream() and streamMapped() respectively.
- DB operations (count, find, findOne, update and updateOne) are now avaailable on MongoRealtimeCol and MongoRealtimeDoc classes.

## 1.2.0

- Updated minimum server version to 1.2.0
- Auto reconnect when listening to a list stream and the connection is lost.
- Added sortBy and sortOrderDesc parameters to listStream and listStreamMapped methods to sort the list by an attribute in ascending or descending order.

## 1.1.3

- Changed listStreamMapped to return a broadcast stream so multiple listeners can listen to the same stream.
- Fixed connect and forceConnect methods.

## 1.1.2

- Fixed an issue where socket lose all registered streams after a reconnection.
- Fixed multiple handlers being called many times when listening to the same list stream.
  Here was how to reproduce the issue:

```dart
realtime.listStreamMapped<String?>(
  "usersWithName",
  fromMap: (doc) => doc["name"],
  filter: (value) {
    return value.toString().startsWith("A");
  },
).listen((s) {
  print("Name startsWith A:");
  print(s);
});

realtime.listStreamMapped<String?>(
  "usersWithName",
  fromMap: (doc) => doc["name"],
  filter: (value) {
    return value.toString().startsWith("B");
    },
).listen((s) {
    print("Name startsWith B:");
    print(s);
    });

/** Both streams are listened to the same "usersWithName" streamId
 * So after each "listen", both handlers are called.
 * That means 2x2=4 times after 2 listens, 3x3=9 times after 3 listens, etc.
 * This is fixed now by tracking streamId with a unique registerId for each listen.
 */

```

## 1.1.1

- New way to listen events with `onChange()` method on `MongoRealtimeDB`, `MongoRealtimeCol` and `MongoRealtimeDoc` classes.
- You can now listen to document changes with `MongoRealtime().col(collectionName).doc(docId).onChange()`.
- Support of list streams with `listStream()` and `listStreamMapped<T>()` methods.

## 0.1.1

- New method forceConnect() to force a connection until successful or retries exhausted

## 0.1.0

- autoConnect option (default false) to connect automatically on init()
- Added connect() method to manually connect when autoConnect is false
- Added realtime getter for easier access to the singleton instance
- Added authData parameter to send additional data with the auth token
