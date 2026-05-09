import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// MongoRealtime: A Dart client for MongoDB realtime updates over WebSocket.
///
/// This library provides a realtime MongoDB client that connects through a\n/// WebSocket server, enabling live query subscriptions, optimistic updates,
/// and server-sent events.
///
/// Basic usage:
/// ```dart
/// // Create a client
/// final mongo = MongoRealtime('ws://localhost:3000');
///
/// // Get a collection reference
/// final users = mongo.collection('users');
///
/// // Subscribe to realtime updates
/// users.stream.listen((documents) {
///   print('Updated documents: $documents');
/// });
///
/// // Execute a query
/// final results = await users.where('age', isGreaterThan: 18).find();
/// ```

part 'src/core/cache_manager.dart';
part 'src/core/collection_reference.dart';
part 'src/core/db_watcher.dart';
part 'src/core/document_reference.dart';
part 'src/core/live_query.dart';
part 'src/core/mongo_realtime.dart';
part 'src/core/printer.dart';
part 'src/core/query_builder.dart';
part 'src/core/query_manager.dart';
part 'src/models/db_change.dart';
part 'src/models/document.dart';
part 'src/models/query_definition.dart';
part 'src/models/types.dart';
part 'src/services/web_socket_service.dart';
part 'src/utils/filter_matcher.dart';
part 'src/utils/json_path.dart';
part 'src/utils/json_utils.dart';
part 'src/utils/query_defaults.dart';
part 'src/utils/sort_utils.dart';
part 'src/utils/update_operators.dart';
part 'src/utils/url_normalizer.dart';
part 'src/utils/value_compare.dart';
