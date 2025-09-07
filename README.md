# MongoRealtime 🚀

A Dart package that allows you to listen in real-time to changes in a MongoDB database via a bridge with the Node.js package [`mongo-realtime`](https://www.npmjs.com/package/mongo-realtime).

![Banner](logo.png)

## Features

- Listen to insert, update, delete, replace, drop events on MongoDB collections.
- Filter events by collection or specific document ID.
- Stream changes as Dart events.
- Easily manage multiple listeners.
- Lightweight and efficient.

## Getting Started

### 1. Install the Dart Package

Add `mongo_realtime` to your `pubspec.yaml` or via:

```bash
dart pub add mongo_realtime
```

### 2. Set Up the Node.js Bridge (optional)

This package relies on a Node.js bridge using [mongo-realtime](https://www.npmjs.com/package/mongo-realtime).

Install it with (on the server):

```bash
npm install mongo-realtime
```

Create a simple Node.js server:

```js
const MongoRealtime  = require("mongo-realtime");

// ...server initialization and db connection

// then init realtime with the same connection and server
MongoRealtime.init({
  uri: mongoose.connection,
  server: server,
});
```

Make sure your MongoDB instance is a **replica set**.

==**IMPORTANT NOTE :**== If your server is not using the mongo-reatime package, it should emit [db events](#db-events) itself through a socket.

### 3. Use in Dart

#### Basic usage

```dart
import 'package:mongo_realtime/mongo_realtime.dart';

void main() async {
  MongoRealtime.init("http://my_server:server_port", showLogs: false);

  // After calling init(), you can use MongoRealtime.instance or the getter 'realtime'

  final listener = MongoRealtime.instance.onDbChange(
    callback: (change) => print("Change: ${change.collection}"),
  );

  // connect to the server when autoConnect is false
  MongoRealtime.instance.connect(); // or realtime.connect();

  // Stop listening:
  listener.cancel();
}
```

#### Using auth token

```dart
MongoRealtime.init(
  "http://my_server:server_port",
  token : "my_jwt_token", // or any string
  autoConnect: true, // default is false
  authData: {"role": "admin"}, // optional additional data
);
```

This will send the token to the server before connecting. The server can then verify it and accept or reject the connection.

#### Using multiple instances

```dart
final prodServer = MongoRealtime(
  "http://prod-server-url",
  onConnect: (s) {
    print("Connected to prod server");
  },
);
final devServer = MongoRealtime(
  "http://dev-server-url",
  onConnect: (s) {
    print("Connected to dev server");
  },
);

// Listen to changes
prodServer.onColChange(
  "users",
  callback: (change) => print("users changed on prod"),
);
devServer.onColChange(
  "posts",
  callback: (change) => print("posts changed on dev"),
);
```

#### Specific use cases

```dart
//  Listeners
realtime.onColChange(
  "users",
  docId: "1234",
  types: [MongoChangeType.insert],
); // when got a new user with id 1234

realtime.onDbChange(
  collections: ["notifications", "posts"],
  types: [MongoChangeType.delete],
); // when delete a notification or post

realtime.onDbChange(
  types: [MongoChangeType.drop],
); // when drop any collection
```

#### Using streams instead of callback

```dart
void doSomething(change) {}
void doSomethingOnStream(change) {}

final listener = realtime.onColChange(
  "notifications",
  types: [MongoChangeType.insert],
  callback: doSomething,
); //new notification

listener.stream.listen(doSomethingOnStream);

// Both functions will be called doSomething and doSomethingOnStream when changes
```

#### Listening to specific events

You can listen to any event (even [db events](#db-events)) on the socket juste like with socket.io

```dart
realtime.socket.on("custom-event", (data) {}); 
realtime.socket.on("db:update:users:1234", (data){}); // when user 1234 changes
```

## API Overview

- `MongoRealtime.init(url)`: Connect to your bridge server.
- `MongoRealtime.onColChange(...)`: Listen to collection or doc changes.
- `MongoRealtime.onDbChange(...)`: Listen to one or many collections.

Each listener provides:

- `stream`: A `Stream<MongoChange>`.
- `cancel()`: To remove the listener.

### DB Events

#### 1st level : `db:$operation_type`

- `db:change`
- `db:insert`
- `db:update`
- `db:delete`
- `db:drop`
- `db:replace`
- `db:invalidate`

#### 2nd level : `$1st_level:$collection`

- `db:change:users`
- `db:insert:posts`
- ...

#### 3rd level : `$2nd_level:$document_id`

- `db:update:users:XYZ`
- `db:delete:posts:229`
- ...

## License

MIT License
