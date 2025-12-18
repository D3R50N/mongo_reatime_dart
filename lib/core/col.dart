part of "../mongo_realtime.dart";

typedef _RealtimeUpdateOperations =
    ({
      Map<String, dynamic>? $set,
      Map<String, dynamic>? $inc,
      Map<String, dynamic>? $unset,
      Map<String, dynamic>? $push,
      Map<String, dynamic>? $pull,
      Map<String, dynamic>? $addToSet,
      Map<String, dynamic>? $rename,
      Map<String, dynamic>? $setOnInsert,
    });

// ignore: library_private_types_in_public_api
extension RealtimeUpdateOpsJson on _RealtimeUpdateOperations {
  Map<String, dynamic> toMongo() {
    return {
      if ($set != null) r'$set': $set,
      if ($inc != null) r'$inc': $inc,
      if ($unset != null) r'$unset': $unset,
      if ($push != null) r'$push': $push,
      if ($pull != null) r'$pull': $pull,
      if ($addToSet != null) r'$addToSet': $addToSet,
      if ($rename != null) r'$rename': $rename,
      if ($setOnInsert != null) r'$setOnInsert': $setOnInsert,
    };
  }

  bool get isEmpty => toMongo().isEmpty;
}

/// A listener instance to a specific collection
class _RealtimeCol {
  final String _collection;
  final MongoRealtime _mongoRealtime;

  _RealtimeCol(this._mongoRealtime, String collection)
    : _collection = collection;

  _RealtimeDoc doc(String docId) =>
      _RealtimeDoc(_mongoRealtime, _collection, docId);

  RealtimeListener onChange({
    List<RealtimeChangeType?> types = const [],
    void Function(RealtimeChange change)? callback,
  }) {
    List<String> events = [];
    types = types.where((t) => t != null).toList();
    if (types.isEmpty) types.add(null);
    for (var type in types) {
      events.add(
        _mongoRealtime._buildEventName(collection: _collection, type: type),
      );
    }

    return _mongoRealtime._createListener(events: events, callback: callback);
  }

  Future<int> count([Map<String, dynamic>? query]) async {
    return await _mongoRealtime.socket.emitWithAckAsync("realtime:count", {
      "coll": _collection,
      "query": query,
    });
  }

  Future<dynamic> _emitFindEvent({
    Map<String, dynamic>? query,
    String? id,
    int? limit,
    int? skip,
    bool one = false,
    Map<String, dynamic>? sortBy,
    Map<String, dynamic>? project,
  }) async {
    return _mongoRealtime.socket.emitWithAckAsync("realtime:find", {
      "coll": _collection,
      "query": query,
      "one": one,
      "limit": limit,
      "skip": skip,
      "id": id,
      "sortBy": sortBy,
      "project": project,
    });
  }

  Future<List> find<T>({
    Map<String, dynamic>? query,
    int? limit,
    int? skip,
    Map<String, dynamic>? sortBy,
    Map<String, dynamic>? project,
    T Function(Map<String, dynamic> doc)? map,
  }) async {
    final list = List<Map<String, dynamic>>.from(
      await _emitFindEvent(
        one: false,
        query: query,
        limit: limit,
        skip: skip,
        sortBy: sortBy,
        project: project,
      ),
    );

    if (map == null) return list;

    return list.map(map).toList();
  }

  Future findOne<T>({
    Map<String, dynamic>? query,
    Map<String, dynamic>? project,
    int? skip,
    Map<String, dynamic>? sortBy,
    T Function(Map<String, dynamic> doc)? map,
  }) async {
    final data =
        await _emitFindEvent(
              one: true,
              query: query,
              skip: skip,
              sortBy: sortBy,
              project: project,
            )
            as Map<String, dynamic>?;

    if (map == null) return data;
    if (data == null) return null;

    return map(data);
  }

  Future<int> _emitUpdateEvent({
    required _RealtimeUpdateOperations update,
    Map<String, dynamic>? query,
    bool force = false,
    String? id,
    int? limit,
    int? skip,
    bool one = false,
    Map<String, dynamic>? sortBy,
    Map<String, dynamic>? project,
  }) async {
    query ??= {};
    if (query.keys.isEmpty) {
      if (!force) {
        _mongoRealtime._log(
          "Trying to update on all docs. Pass 'force' to 'true' to bypass.",
          PrintType.warning,
        );
        return 0;
      }
    }

    return (await _mongoRealtime.socket.emitWithAckAsync("realtime:update", {
              "coll": _collection,
              "query": query,
              "update": update.toMongo(),
              "one": one,
              "limit": limit,
              "skip": skip,
              "id": id,
              "sortBy": sortBy,
              "project": project,
            }))
            as int? ??
        0;
  }

  Future<int> update<T>({
    Map<String, dynamic>? $set,
    Map<String, dynamic>? $inc,
    Map<String, dynamic>? $unset,
    Map<String, dynamic>? $push,
    Map<String, dynamic>? $pull,
    Map<String, dynamic>? $addToSet,
    Map<String, dynamic>? $rename,
    Map<String, dynamic>? $setOnInsert,
    Map<String, dynamic>? query,
    bool force = false,
    int? limit,
    int? skip,
    Map<String, dynamic>? sortBy,
    Map<String, dynamic>? project,
  }) async {
    final updateData = (
      $set: $set,
      $inc: $inc,
      $unset: $unset,
      $push: $push,
      $pull: $pull,
      $addToSet: $addToSet,
      $rename: $rename,
      $setOnInsert: $setOnInsert,
    );
    return await _emitUpdateEvent(
      one: false,
      update: updateData,
      force: force,
      query: query,
      limit: limit,
      skip: skip,
      sortBy: sortBy,
      project: project,
    );
  }

  Future<int> updateOne<T>({
    Map<String, dynamic>? $set,
    Map<String, dynamic>? $inc,
    Map<String, dynamic>? $unset,
    Map<String, dynamic>? $push,
    Map<String, dynamic>? $pull,
    Map<String, dynamic>? $addToSet,
    Map<String, dynamic>? $rename,
    Map<String, dynamic>? $setOnInsert,
    Map<String, dynamic>? query,
    bool force = false,
    Map<String, dynamic>? project,
    int? skip,
    Map<String, dynamic>? sortBy,
  }) async {
    final updateData = (
      $set: $set,
      $inc: $inc,
      $unset: $unset,
      $push: $push,
      $pull: $pull,
      $addToSet: $addToSet,
      $rename: $rename,
      $setOnInsert: $setOnInsert,
    );
    return await _emitUpdateEvent(
      one: true,
      update: updateData,
      force: force,
      query: query,
      skip: skip,
      sortBy: sortBy,
      project: project,
    );
  }
}
