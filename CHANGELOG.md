# Changelog

## 1.1.0

* New way to listen events with `onChange()` method on `MongoRealtimeDB`, `MongoRealtimeCol` and `MongoRealtimeDoc` classes.
* You can now listen to document changes with `MongoRealtime().col(collectionName).doc(docId).onChange()`.
* Support of list streams with `listStream()` and `listStreamMapped<T>()` methods.

## 0.1.1

* New method forceConnect() to force a connection until successful or retries exhausted

## 0.1.0

* autoConnect option (default false) to connect automatically on init()
* Added connect() method to manually connect when autoConnect is false
* Added realtime getter for easier access to the singleton instance
* Added authData parameter to send additional data with the auth token
