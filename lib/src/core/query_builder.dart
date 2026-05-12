part of '../../mongo_realtime.dart';

/// Builder for realtime collection queries.
///
/// Use this builder to compose filters, sorting, and limits before fetching or
/// subscribing to results.
class RealtimeQueryBuilder<T> {
  RealtimeQueryBuilder({
    required MongoRealtime client,
    required String collection,
    FromJson<T>? fromJson,
    JsonMap? filter,
    Map<String, int>? sort,
    int? limit,
  }) : _client = client,
       _collection = collection,
       _fromJson = fromJson,
       _ast = _QueryAst.fromFilter(filter),
       _sort = LinkedHashMap<String, int>.from(sort ?? const <String, int>{}),
       _limit = limit;

  RealtimeQueryBuilder._internal({
    required MongoRealtime client,
    required String collection,
    FromJson<T>? fromJson,
    required _QueryAst ast,
    required Map<String, int> sort,
    required int? limit,
  }) : _client = client,
       _collection = collection,
       _fromJson = fromJson,
       _ast = ast,
       _sort = LinkedHashMap<String, int>.from(sort),
       _limit = limit;

  final MongoRealtime _client;
  final String _collection;
  final FromJson<T>? _fromJson;
  final _QueryAst _ast;
  final Map<String, int> _sort;
  final int? _limit;

  JsonMap get _compiledFilter => _ast.compile();

  /// Performs an update on all documents matching the query filter using MongoDB update operators.
  /// The update will be applied atomically on the server. If `optimistic` is true, the cache will be updated immediately with the expected changes, and then reconciled with the server response when it arrives. If `optimistic` is false, the cache will only be updated when the server confirms the update.
  /// The `update` parameter should be a map containing MongoDB update operators like `$set`, `$unset`, `$inc`, `$push`, `$pull`, `$addToSet`, and `$rename`. For example:
  /// ```dart
  /// queryBuilder.update(
  ///  $set: {'status': 'active'},
  /// $inc: {'loginCount': 1},
  /// );
  /// ```
  Future<void> update({
    JsonMap? $set,
    JsonMap? $unset,
    JsonMap? $inc,
    JsonMap? $push,
    JsonMap? $pull,
    JsonMap? $addToSet,
    JsonMap? $rename,
    JsonMap? additionalUpdate,
    bool optimistic = false,
  }) {
    final update = buildUpdateMap(
      set: $set,
      unset: $unset,
      inc: $inc,
      push: $push,
      pull: $pull,
      addToSet: $addToSet,
      rename: $rename,
      additionalUpdate: additionalUpdate,
    );

    return _client.update(
      _collection,
      update: update,
      filter: definition.filter,
      optimistic: optimistic,
    );
  }

  /// Adds a where clause to the query with the specified field and condition. The condition can be one of the following operators:
  /// - `isEqualTo`: Matches documents where the field is equal to the specified value.
  /// - `isNotEqualTo`: Matches documents where the field is not equal to the specified value.
  /// - `isGreaterThan`: Matches documents where the field is greater than the specified value.
  /// - `isGreaterOrEqualTo`: Matches documents where the field is greater than or equal to the specified value.
  /// - `isLowerThan`: Matches documents where the field is less than the specified value.
  /// - `isLowerOrEqualTo`: Matches documents where the field is less than or equal to the specified value.
  /// - `arrayContains`: Matches documents where the field is an array that contains the specified value.
  /// - `isIn`: Matches documents where the field's value is in the specified list of values.
  /// - `matches`: Matches documents where the field matches the specified pattern. The pattern can be a string (for simple substring matching) or a regular expression (for more complex pattern matching).
  RealtimeQueryBuilder<T> where(
    String field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterOrEqualTo,
    Object? isLowerThan,
    Object? isLowerOrEqualTo,
    Object? arrayContains,
    Iterable? isIn,
    Object? matches,
  }) {
    return _copyWith(
      ast: _ast.addAnd(
        _buildQueryClause(
          field,
          isEqualTo: isEqualTo,
          isNotEqualTo: isNotEqualTo,
          isGreaterThan: isGreaterThan,
          isGreaterOrEqualTo: isGreaterOrEqualTo,
          isLowerThan: isLowerThan,
          isLowerOrEqualTo: isLowerOrEqualTo,
          arrayContains: arrayContains,
          isIn: isIn,
          matches: matches,
        ),
      ),
    );
  }

  /// Adds an `$or` block to the query with the specified group of clauses. Each clause in the group is defined using the same operators as the `where` method. For example:
  /// ```dart
  /// queryBuilder.or((group) {
  ///   group.where('status', isEqualTo: 'active');
  ///   group.where('age', isGreaterThan: 30);
  /// }).or((group) {
  ///   group.where('role', isEqualTo: 'admin');
  ///  group.where('lastLogin', isLowerThan: DateTime.now().subtract(Duration(days: 30)));
  /// });
  /// ```
  /// This will produce a query filter equivalent to:
  /// ```json
  /// {
  ///   "$and": [
  ///     {
  ///       "$or": [
  ///         {"status": "active"},
  ///         {"age": {"$gt": 30}}
  ///       ]
  ///     },
  ///     {
  ///       "$or": [
  ///         {"role": "admin"},
  ///         {"lastLogin": {"$lt": "Time value representing 30 days ago"}}
  ///       ]
  ///     }
  ///  ]
  /// }
  /// ```
  RealtimeQueryBuilder<T> or(
    void Function(RealtimeQueryOrGroupBuilder group) build,
  ) {
    final group = RealtimeQueryOrGroupBuilder._();
    build(group);

    if (group._clauses.isEmpty) {
      return this;
    }

    return _copyWith(ast: _ast.addOr(group._clauses));
  }

  RealtimeQueryBuilder<T> sort(String field, {bool descending = false}) {
    final nextSort = LinkedHashMap<String, int>.from(_sort);
    nextSort[field] = descending ? -1 : 1;
    return _copyWith(sort: nextSort);
  }

  /// Applies a sort order to the query using a field map.
  RealtimeQueryBuilder<T> orderBy(Map<String, int> sort) {
    return _copyWith(sort: LinkedHashMap<String, int>.from(sort));
  }

  /// Limits the number of documents returned by the query.
  RealtimeQueryBuilder<T> take(int limit) {
    return _copyWith(limit: limit);
  }

  /// Alias for [take], used to set the maximum number of documents.
  RealtimeQueryBuilder<T> limit(int limit) => take(limit);

  /// The compiled query definition used for fetch and subscription operations.
  RealtimeQueryDefinition get definition => RealtimeQueryDefinition(
    collection: _collection,
    filter: _compiledFilter,
    sort: _sort,
    limit: _limit,
  );

  /// A realtime stream of documents matching the current query.
  Stream<List<RealtimeDocument<T>>> get stream {
    return _client._queryManager.streamQuery<T>(
      definition,
      fromJson: _fromJson,
    );
  }

  /// A realtime stream of typed values matching the current query.
  Stream<List<T>> get streamWithValue {
    return stream.map(
      (documents) =>
          documents.map((document) => _requireDocumentValue(document)).toList(),
    );
  }

  /// Fetches the current matching documents for this query once.
  Future<List<RealtimeDocument<T>>> find() {
    return _client._queryManager.fetchQuery<T>(definition, fromJson: _fromJson);
  }

  RealtimeQueryBuilder<T> _copyWith({
    _QueryAst? ast,
    Map<String, int>? sort,
    int? limit,
  }) {
    return RealtimeQueryBuilder<T>._internal(
      client: _client,
      collection: _collection,
      fromJson: _fromJson,
      ast: ast ?? _ast,
      sort: sort ?? _sort,
      limit: limit ?? _limit,
    );
  }

  T _requireDocumentValue(RealtimeDocument<T> document) {
    final value = document.value;
    if (value != null) {
      return value;
    }

    throw StateError(
      'MongoRealtime could not resolve a value of type $T for document '
      '${document.id.isEmpty ? document.data : document.id}. '
      'Provide a fromJson converter or use stream to access raw documents.',
    );
  }
}

/// Helper builder for composing `$or` query groups.
class RealtimeQueryOrGroupBuilder {
  RealtimeQueryOrGroupBuilder._();

  final List<_QueryAstNode> _clauses = <_QueryAstNode>[];

  /// Adds a clause to the current `$or` group.
  ///
  /// Use the same operators as [RealtimeQueryBuilder.where].
  RealtimeQueryOrGroupBuilder where(
    String field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isGreaterThan,
    Object? isGreaterOrEqualTo,
    Object? isLowerThan,
    Object? isLowerOrEqualTo,
    Object? arrayContains,
    Iterable? isIn,
    Object? matches,
  }) {
    _clauses.add(
      _buildQueryClause(
        field,
        isEqualTo: isEqualTo,
        isNotEqualTo: isNotEqualTo,
        isGreaterThan: isGreaterThan,
        isGreaterOrEqualTo: isGreaterOrEqualTo,
        isLowerThan: isLowerThan,
        isLowerOrEqualTo: isLowerOrEqualTo,
        arrayContains: arrayContains,
        matches: matches,
        isIn: isIn,
      ),
    );
    return this;
  }
}

abstract class _QueryAstNode {
  JsonMap compile();
}

class _QueryAst {
  _QueryAst({Iterable<_QueryAstNode> andClauses = const <_QueryAstNode>[]})
    : andClauses = List.unmodifiable(andClauses);

  factory _QueryAst.fromFilter(JsonMap? filter) {
    if (filter == null || filter.isEmpty) {
      return _QueryAst();
    }

    return _QueryAst(andClauses: <_QueryAstNode>[_RawFilterNode(filter)]);
  }

  final List<_QueryAstNode> andClauses;

  _QueryAst addAnd(_QueryAstNode clause) {
    return _QueryAst(andClauses: <_QueryAstNode>[...andClauses, clause]);
  }

  _QueryAst addOr(Iterable<_QueryAstNode> clauses) {
    return _QueryAst(
      andClauses: <_QueryAstNode>[...andClauses, _OrNode(clauses)],
    );
  }

  JsonMap compile() {
    return _compileAndGroup(andClauses) ?? <String, dynamic>{};
  }

  JsonMap? _compileAndGroup(List<_QueryAstNode> clauses) {
    if (clauses.isEmpty) {
      return null;
    }
    if (clauses.length == 1) {
      return clauses.single.compile();
    }

    return <String, dynamic>{
      r'$and': clauses
          .map((clause) => clause.compile())
          .toList(growable: false),
    };
  }
}

class _OrNode implements _QueryAstNode {
  _OrNode(Iterable<_QueryAstNode> clauses)
    : _clauses = List.unmodifiable(clauses);

  final List<_QueryAstNode> _clauses;

  @override
  JsonMap compile() {
    return <String, dynamic>{
      r'$or': _clauses
          .map((clause) => clause.compile())
          .toList(growable: false),
    };
  }
}

class _RawFilterNode implements _QueryAstNode {
  _RawFilterNode(JsonMap filter) : _filter = deepCopyMap(filter);

  final JsonMap _filter;

  @override
  JsonMap compile() => deepCopyMap(_filter);
}

class _ConditionNode implements _QueryAstNode {
  _ConditionNode({
    required this.field,
    this.operator,
    required this.value,
    this.regexOptions,
  });

  final String field;
  final String? operator;
  final Object? value;
  final String? regexOptions;

  @override
  JsonMap compile() {
    if (operator == null) {
      return <String, dynamic>{field: deepCopyJson(value)};
    }

    if (operator == r'$regex') {
      return <String, dynamic>{
        field: <String, dynamic>{
          r'$regex': value,
          if (regexOptions != null && regexOptions!.isNotEmpty)
            r'$options': regexOptions,
        },
      };
    }

    return <String, dynamic>{
      field: <String, dynamic>{operator!: deepCopyJson(value)},
    };
  }
}

_QueryAstNode _buildQueryClause(
  String field, {
  required Object? isEqualTo,
  required Object? isNotEqualTo,
  required Object? isGreaterThan,
  required Object? isGreaterOrEqualTo,
  required Object? isLowerThan,
  required Object? isLowerOrEqualTo,
  required Object? arrayContains,
  required Iterable? isIn,
  required Object? matches,
}) {
  if (field.trim().isEmpty) {
    throw ArgumentError.value(
      field,
      'field',
      'Expected a non-empty field name or a JSON filter map.',
    );
  }

  final operators = <_ConditionNode>[
    if (isEqualTo != null)
      _ConditionNode(field: field, value: deepCopyJson(isEqualTo)),
    if (isNotEqualTo != null)
      _ConditionNode(
        field: field,
        operator: r'$ne',
        value: deepCopyJson(isNotEqualTo),
      ),
    if (isGreaterThan != null)
      _ConditionNode(
        field: field,
        operator: r'$gt',
        value: deepCopyJson(isGreaterThan),
      ),
    if (isGreaterOrEqualTo != null)
      _ConditionNode(
        field: field,
        operator: r'$gte',
        value: deepCopyJson(isGreaterOrEqualTo),
      ),
    if (isLowerThan != null)
      _ConditionNode(
        field: field,
        operator: r'$lt',
        value: deepCopyJson(isLowerThan),
      ),
    if (isLowerOrEqualTo != null)
      _ConditionNode(
        field: field,
        operator: r'$lte',
        value: deepCopyJson(isLowerOrEqualTo),
      ),
    if (arrayContains != null)
      _ConditionNode(field: field, value: deepCopyJson(arrayContains)),
    if (isIn != null)
      _ConditionNode(
        field: field,
        operator: r'$in',
        value: _normalizeIterableOperator(isIn, 'isIn'),
      ),
    if (matches != null) _normalizePatternOperator(field, matches),
  ];

  if (operators.isEmpty) {
    throw ArgumentError('A where clause must specify exactly one operator.');
  }

  if (operators.length > 1) {
    throw ArgumentError(
      'A where clause supports exactly one operator. Split combined logic into multiple where() calls or an or() block.',
    );
  }

  return operators.single;
}

List<Object?> _normalizeIterableOperator(Iterable? value, String operatorName) {
  if (value is! Iterable) {
    throw ArgumentError.value(
      value,
      operatorName,
      'Expected an Iterable value.',
    );
  }

  return value.map(deepCopyJson).toList(growable: false);
}

_ConditionNode _normalizePatternOperator(String field, Object? value) {
  if (value is RegExp) {
    final options =
        StringBuffer()
          ..write(value.isCaseSensitive ? '' : 'i')
          ..write(value.isMultiLine ? 'm' : '');

    return _ConditionNode(
      field: field,
      operator: r'$regex',
      value: value.pattern,
      regexOptions: options.isEmpty ? null : options.toString(),
    );
  }

  if (value is String) {
    return _ConditionNode(field: field, operator: r'$regex', value: value);
  }

  throw ArgumentError.value(
    value,
    'matches',
    'Expected a String or RegExp value.',
  );
}
