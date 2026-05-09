# MongoRealtime

A pure Dart package that allows you to listen in real-time to changes in a MongoDB database via a WebSocket connection to a bridge server using the Node.js package [`mongo-realtime`](https://www.npmjs.com/package/mongo-realtime).

![Banner](logo.png)

## Features

- Listen to insert, update, delete events on MongoDB collections in real-time.
- Filter and sort documents with a fluent query builder API.
- Type-safe document mapping with generic types.
- Stream changes as Dart events.
- Optimistic updates with offline support.
- Lightweight, pure Dart - no Flutter dependencies.
- Automatic connection management and reconnection.

## Getting Started

### 1. Install the Dart Package

Add `mongo_realtime` to your `pubspec.yaml` or via:

```bash
dart pub add mongo_realtime
```

### 2. Set Up the Node.js Bridge (optional)

This package relies on a Node.js bridge using [mongo-realtime](https://www.npmjs.com/package/mongo-realtime).

Install it (on the server):

```bash
npm install mongo-realtime
```

Create a simple Node.js server:

```js
const { MongoRealTimeServer } = require("mongo-realtime");

const server = new MongoRealTimeServer({
  mongoUri: "mongodb://localhost:27017/mydb",
  dbName: "mydb",
});

await server.start();
```

Make sure your MongoDB instance is a **replica set**.

**Important:** If your server is not using the `mongo-realtime` package, it should emit [db events](#db-events) itself through a socket.

### 3. Use in Dart

#### Basic usage

```dart
import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  // Connect to the server
  // Use `connect` for later access  to the singleton instance `MongoRealtime.instance` or `realtime`
  MongoRealtime.connect('ws://localhost:3000');
  realtime.collection('users').stream.listen((documents) {
    print('Users: ${documents.map((doc) => doc.id).toList()}');
  });

  // Or create a new instance:
  final client = MongoRealtime('ws://localhost:3000');

  // Stream all documents from a collection
  client.collection('users').stream.listen((documents) {
    print('Users: ${documents.map((doc) => doc.id).toList()}');
  });

  // Listen to database changes
  client.watch.onInsert((change) {
    print('Inserted: ${change.docId} in ${change.collection}');
  });

  // Using a different url schema (e.g http instead of ws) also works, it will be converted to ws internally
  final client2 = MongoRealtime('localhost:3000'); // This will connect to ws://localhost:3000
  final client3 = MongoRealtime('https://my-api.com'); // This will connect to wss://my-api.com
}
```

#### Using auth data

If your server is setup with authentication, you may need to provide authentication data (e.g. a JWT token) when connecting.
See [MongoRealtime Authentication](https://www.npmjs.com/package/mongo-realtime#authentication) for more details on the server side setup.

```dart
MongoRealtime.connect(
  'my_server:3000',
  authData: 'my_jwt_token',
);

// or a Map for more complex auth data
MongoRealtime.connect(
  'my_server:3000',
  authData: {
    'token': 'my_jwt_token',
    'userId': '123',
  },
);
```

#### Query with filters and sorting

```dart

// Find documents with query
final users = await realtime.collection('users')
  .where('age', isGreaterThan: 18)
  .where('role', isEqualTo: 'admin')
  .sort('createdAt', descending: true)
  .limit(10)
  .find();

// Stream with real-time updates
realtime.collection('users')
  .where('status', isEqualTo: 'active')
  .stream
  .listen((documents) {
    print('Active users: $documents');
  });

// `or` queries
// All clauses inside `or` builder are combined with OR, and the result is combined with the rest of the query with AND
realtime.collection('users')
  .where('age', isGreaterThan: 18)
  .or((q) {
    // This will match users who are adults admin OR adults with active status
    q.where('role', isEqualTo: 'admin');
    q.where('status', isEqualTo: 'active');
  })
  .stream.listen((documents) {
    print('Users who are either adults or active admins: $documents');
  });
```

#### Type-safe document mapping

```dart
class User {
  final String id;
  final String name;
  final int age;

  User.fromJson(Map<String, dynamic> json)
    : id = json['_id'],
      name = json['name'],
      age = json['age'];
}

// Map documents to User objects
final users = await realtime.collection<User>('users',
  fromJson: (json) => User.fromJson(json),
).find();

users.forEach((doc) {
  print('${doc.value?.name} (${doc.value?.age})');
});
```

#### Insert, update, delete

```dart
final collection = realtime.collection('users');

// Insert
await collection.insert({'name': 'John', 'age': 30});

// Update
await collection.update(
  $set: {'age': 31}
  filter: {'name': 'John'},
);
// or
await collection.where('name', isEqualTo: 'John').update($set: {'age': 31});

// Delete
await collection.delete(filter: {'name': 'John'});
```

#### Document-specific operations

```dart
final doc = realtime.collection('users').doc('user_123');

// Get a specific document
final user = await doc.find();

// Listen to changes on a specific document
doc.stream().listen((user) {
  print('User updated: $user');
});

// Update a specific document
await doc.update($set: {'age': 25});

// Delete a specific document
await doc.delete();
```

#### Database change watchers

```dart
// Listen to all changes
realtime.watch.onChange((change) {
  print('Changed: ${change.docId} in ${change.collection}');
});

// Listen to specific collection
realtime.collection('users').watch.onInsert((change) {
  print('New user: ${change.docId}');
});

// Listen to specific document
realtime.collection('users').doc('123').watch.onUpdate((change) {
  print('User 123 updated');
});
```

#### Multiple server instances

```dart
final prodServer = MongoRealtime('ws://prod-server:3000');
final devServer = MongoRealtime('ws://dev-server:3000');

// Listen to changes on different servers
prodServer.collection('users').stream.listen(
  (users) => print('Prod users: $users')
);

devServer.collection('users').stream.listen(
  (users) => print('Dev users: $users')
);
```

#### Using optimistic updates

```dart
final collection = client.collection('users');

// Optimistic insert - update UI immediately
await collection.insert(
  {'_id': 'new_user', 'name': 'Jane'},
  optimistic: true,
);

// The document appears in streams immediately,
// then syncs with the server
// Default is `optimistic: false` which ensures the operation is confirmed by the server before updating streams
```

## API Overview

### Main Classes

- **`MongoRealtime`**: Main client for connecting to the realtime server.
  - `MongoRealtime.connect(url, authData?)`: Connect to a WebSocket server (singleton).
  - `MongoRealtime(url, authData?)`: Create a new instance.
  - `instance`: Access the singleton instance.
  - `realtime`: Global getter for the singleton instance.

### Collection & Document Access

- **`collection(name, fromJson?)`**: Get a collection reference.
  - Returns `RealtimeCollectionReference<T>`.

- **`RealtimeCollectionReference<T>`**:
  - `where(field, ...)`: Add filter clause (supports `isEqualTo`, `isNotEqualTo`, `isGreaterThan`, `isGreaterOrEqualTo`, `isLowerThan`, `isLowerOrEqualTo`, `arrayContains`, `isIn`, `matches`).
  - `or(builder)`: Add OR clause.
  - `sort(field, descending?)`: Sort by field.
  - `limit(count)`: Limit results.
  - `stream`: Stream of all matching documents.
  - `find()`: Fetch all matching documents once.
  - `doc(id)`: Get a document reference.
  - `insert(doc, optimistic?)`: Insert a document.
  - `update(update, filter?, optimistic?)`: Update documents.
  - `delete(filter?, optimistic?)`: Delete documents.

- **`doc(id)`**: Get a document reference.
  - Returns `RealtimeDocumentReference<T>`.

- **`RealtimeDocumentReference<T>`**:
  - `stream()`: Stream this document's changes.
  - `find()`: Fetch this document once.
  - `update(update, optimistic?)`: Update this document.
  - `delete(optimistic?)`: Delete this document.

### Query Builder

- **`RealtimeQueryBuilder<T>`**:
  - `where(field, ...)`: Add AND clause with field conditions.
  - `or(builder)`: Add OR clause with multiple conditions.
  - `sort(field, descending?)`: Add sort order.
  - `limit(count)`: Limit number of documents.
  - `stream`: Get as a broadcast stream.
  - `find()`: Execute query once.

### Database Watchers

- **`DbWatcher`**: Watch for database changes.
  - `onChange(handler)`: Listen to any change.
  - `onInsert(handler)`: Listen to inserts only.
  - `onUpdate(handler)`: Listen to updates only.
  - `onDelete(handler)`: Listen to deletes only.
  - `offChange(handler)`: Unsubscribe from changes.
  - `offInsert(handler)`: Unsubscribe from inserts.
  - `offUpdate(handler)`: Unsubscribe from updates.
  - `offDelete(handler)`: Unsubscribe from deletes.

### Return Types

- **`RealtimeDocument<T>`**: A document with metadata.
  - `id`: Document ID.
  - `data`: Raw document map.
  - `value`: Typed value (if `fromJson` was provided).

- **`RealtimeDbChange`**: A database change event.
  - `type`: Insert, update, delete, or change.
  - `collection`: Collection name.
  - `docId`: Document ID.
  - `fullDocument`: Full document (if available).
  - `cast<T>(fromJson)`: Cast to typed model.
  - `tryCast<T>(fromJson)`: Try to cast to typed model.

## License

MIT License
