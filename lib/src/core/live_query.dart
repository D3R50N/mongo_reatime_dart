part of '../../mongo_realtime.dart';

class RealtimeLiveQuery {
  RealtimeLiveQuery(this.definition);

  final RealtimeQueryDefinition definition;
  final StreamController<List<JsonMap>> controller =
      StreamController<List<JsonMap>>.broadcast();

  int listenerCount = 0;
  bool hasSnapshot = false;
  List<JsonMap> _documents = const [];

  Stream<List<JsonMap>> get stream => controller.stream;

  List<JsonMap> get documents =>
      _documents.map(deepCopyMap).toList(growable: false);

  void replaceDocuments(
    List<JsonMap> documents, {
    bool forceEmit = false,
    bool markHydrated = true,
  }) {
    final copied = documents.map(deepCopyMap).toList(growable: false);
    final changed = forceEmit || !_sameDocuments(_documents, copied);
    _documents = copied;
    hasSnapshot = markHydrated;

    if (changed) {
      controller.add(this.documents);
    }
  }

  void clearHydration() {
    hasSnapshot = false;
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    controller.addError(error, stackTrace);
  }

  Future<void> dispose() => controller.close();

  bool _sameDocuments(List<JsonMap> left, List<JsonMap> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (!deepEquals(left[index], right[index])) {
        return false;
      }
    }

    return true;
  }
}
