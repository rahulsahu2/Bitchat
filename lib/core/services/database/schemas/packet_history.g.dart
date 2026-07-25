// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'packet_history.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPacketHistoryCollection on Isar {
  IsarCollection<PacketHistory> get packetHistorys => this.collection();
}

const PacketHistorySchema = CollectionSchema(
  name: r'PacketHistory',
  id: 9028159565968162645,
  properties: {
    r'packetId': PropertySchema(
      id: 0,
      name: r'packetId',
      type: IsarType.string,
    ),
    r'timestamp': PropertySchema(
      id: 1,
      name: r'timestamp',
      type: IsarType.dateTime,
    )
  },
  estimateSize: _packetHistoryEstimateSize,
  serialize: _packetHistorySerialize,
  deserialize: _packetHistoryDeserialize,
  deserializeProp: _packetHistoryDeserializeProp,
  idName: r'id',
  indexes: {
    r'packetId': IndexSchema(
      id: 3245725721812872481,
      name: r'packetId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'packetId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'timestamp': IndexSchema(
      id: 1852253767416892198,
      name: r'timestamp',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'timestamp',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _packetHistoryGetId,
  getLinks: _packetHistoryGetLinks,
  attach: _packetHistoryAttach,
  version: '3.1.0+1',
);

int _packetHistoryEstimateSize(
  PacketHistory object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.packetId.length * 3;
  return bytesCount;
}

void _packetHistorySerialize(
  PacketHistory object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.packetId);
  writer.writeDateTime(offsets[1], object.timestamp);
}

PacketHistory _packetHistoryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PacketHistory();
  object.packetId = reader.readString(offsets[0]);
  object.timestamp = reader.readDateTime(offsets[1]);
  return object;
}

P _packetHistoryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _packetHistoryGetId(PacketHistory object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _packetHistoryGetLinks(PacketHistory object) {
  return [];
}

void _packetHistoryAttach(
    IsarCollection<dynamic> col, Id id, PacketHistory object) {}

extension PacketHistoryByIndex on IsarCollection<PacketHistory> {
  Future<PacketHistory?> getByPacketId(String packetId) {
    return getByIndex(r'packetId', [packetId]);
  }

  PacketHistory? getByPacketIdSync(String packetId) {
    return getByIndexSync(r'packetId', [packetId]);
  }

  Future<bool> deleteByPacketId(String packetId) {
    return deleteByIndex(r'packetId', [packetId]);
  }

  bool deleteByPacketIdSync(String packetId) {
    return deleteByIndexSync(r'packetId', [packetId]);
  }

  Future<List<PacketHistory?>> getAllByPacketId(List<String> packetIdValues) {
    final values = packetIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'packetId', values);
  }

  List<PacketHistory?> getAllByPacketIdSync(List<String> packetIdValues) {
    final values = packetIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'packetId', values);
  }

  Future<int> deleteAllByPacketId(List<String> packetIdValues) {
    final values = packetIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'packetId', values);
  }

  int deleteAllByPacketIdSync(List<String> packetIdValues) {
    final values = packetIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'packetId', values);
  }

  Future<Id> putByPacketId(PacketHistory object) {
    return putByIndex(r'packetId', object);
  }

  Id putByPacketIdSync(PacketHistory object, {bool saveLinks = true}) {
    return putByIndexSync(r'packetId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByPacketId(List<PacketHistory> objects) {
    return putAllByIndex(r'packetId', objects);
  }

  List<Id> putAllByPacketIdSync(List<PacketHistory> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'packetId', objects, saveLinks: saveLinks);
  }
}

extension PacketHistoryQueryWhereSort
    on QueryBuilder<PacketHistory, PacketHistory, QWhere> {
  QueryBuilder<PacketHistory, PacketHistory, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhere> anyTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'timestamp'),
      );
    });
  }
}

extension PacketHistoryQueryWhere
    on QueryBuilder<PacketHistory, PacketHistory, QWhereClause> {
  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause> packetIdEqualTo(
      String packetId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'packetId',
        value: [packetId],
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      packetIdNotEqualTo(String packetId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packetId',
              lower: [],
              upper: [packetId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packetId',
              lower: [packetId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packetId',
              lower: [packetId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'packetId',
              lower: [],
              upper: [packetId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      timestampEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'timestamp',
        value: [timestamp],
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      timestampNotEqualTo(DateTime timestamp) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [timestamp],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'timestamp',
              lower: [],
              upper: [timestamp],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      timestampGreaterThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [timestamp],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      timestampLessThan(
    DateTime timestamp, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [],
        upper: [timestamp],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterWhereClause>
      timestampBetween(
    DateTime lowerTimestamp,
    DateTime upperTimestamp, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'timestamp',
        lower: [lowerTimestamp],
        includeLower: includeLower,
        upper: [upperTimestamp],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension PacketHistoryQueryFilter
    on QueryBuilder<PacketHistory, PacketHistory, QFilterCondition> {
  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'packetId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'packetId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'packetId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'packetId',
        value: '',
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      packetIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'packetId',
        value: '',
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      timestampEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      timestampGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      timestampLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timestamp',
        value: value,
      ));
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterFilterCondition>
      timestampBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timestamp',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension PacketHistoryQueryObject
    on QueryBuilder<PacketHistory, PacketHistory, QFilterCondition> {}

extension PacketHistoryQueryLinks
    on QueryBuilder<PacketHistory, PacketHistory, QFilterCondition> {}

extension PacketHistoryQuerySortBy
    on QueryBuilder<PacketHistory, PacketHistory, QSortBy> {
  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> sortByPacketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packetId', Sort.asc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy>
      sortByPacketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packetId', Sort.desc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> sortByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy>
      sortByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension PacketHistoryQuerySortThenBy
    on QueryBuilder<PacketHistory, PacketHistory, QSortThenBy> {
  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> thenByPacketId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packetId', Sort.asc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy>
      thenByPacketIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'packetId', Sort.desc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy> thenByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.asc);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QAfterSortBy>
      thenByTimestampDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timestamp', Sort.desc);
    });
  }
}

extension PacketHistoryQueryWhereDistinct
    on QueryBuilder<PacketHistory, PacketHistory, QDistinct> {
  QueryBuilder<PacketHistory, PacketHistory, QDistinct> distinctByPacketId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'packetId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PacketHistory, PacketHistory, QDistinct> distinctByTimestamp() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timestamp');
    });
  }
}

extension PacketHistoryQueryProperty
    on QueryBuilder<PacketHistory, PacketHistory, QQueryProperty> {
  QueryBuilder<PacketHistory, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PacketHistory, String, QQueryOperations> packetIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'packetId');
    });
  }

  QueryBuilder<PacketHistory, DateTime, QQueryOperations> timestampProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timestamp');
    });
  }
}
