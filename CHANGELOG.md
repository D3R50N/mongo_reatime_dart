# Changelog

## 3.0.1

- Fixed `RealtimeQueryBuilder.or()` so each `or(...)` block is preserved as its own `$or` group inside the root `$and` chain instead of flattening all clauses into a single root-level `$or`.
- Fixed `cache_manager` so it prevent 

## 3.0.0 (Breaking Changes)

- **Major Refactoring**: Complete redesign of the library architecture with improved separation of concerns.
- Replaced `socket_io_client` with `web_socket_channel` for better WebSocket management.
- Removed `flutter_reactive` dependency, simplified reactive patterns with native Dart streams.
- Removed Flutter dependency - library is now pure Dart.
- **New API**: Changed from `MongoRealtime.init()` to `MongoRealtime.connect()`.
- **Collection API**: Replaced direct stream methods with `collection(name)` and `doc(id)` accessors.
- **Query Builder**: Added `RealtimeQueryBuilder` for fluent query construction with `where()`, `sort()`, `limit()` methods.
- **Document References**: New `RealtimeDocumentReference` and `RealtimeCollectionReference` classes for better type safety.
- **DB Watchers**: Replaced `onChange()` callbacks with `DbWatcher` for listening to database changes (insert, update, delete).
- **Event Processing**: New `RealtimeEventProcessor` for handling server messages with better error handling.
- **Caching**: Improved internal caching with `RealtimeCacheManager` for better performance.
- **Query Manager**: New `RealtimeQueryManager` for managing active queries and subscriptions.
- Removed `RealtimeBuilder` Flutter widget - use native `StreamBuilder` instead.
- Removed `Uuid` utility class - generate IDs externally.
- Improved logging with Dart's `developer.log`.

## 2.1.1

- Updated `flutter_reactive` dependency to `^1.0.1`.

## 2.1.0

- Updated deprecated Readme and dart docs comments.
- Fixed realtime stream filtering and sorting so `filter` and `sortBy` are now applied to emitted results.
- Improved socket stream lifecycle management to avoid duplicate handlers and stale realtime registrations across rebuilds and reconnections.
- Added cleanup for socket listeners and cached realtime stream state when a stream is no longer observed.
- Updated `RealtimeBuilder` to reuse its stream instance and refresh it only when parameters change.
- Updated example app to a concrete Flutter realtime dashboard demo.

## 2.0.4

- No more use `sortOrderDesc`. Just use `reverse`

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
