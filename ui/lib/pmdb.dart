import 'dart:io';

import 'package:fixnum/fixnum.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pneumamesh/pb/message.pb.dart';

class DbSchema {
  static const dbVersion = 2;

  static const accountInfoTable = 'account_info';
  static const peersTable = 'peers';
  static const messagesTable = 'messages';
  static const messageMetaTable = 'message_meta';
  static const roomsTable = 'rooms';
  static const roomMetaTable = 'room_meta';
  static const cascadesTable = 'cascades';
  static const cascadeMetaTable = 'cascade_meta';

  static const colPeerId = 'peer_id';
  static const colUserName = 'username';
  static const colRegisterTimestamp = 'register_timestamp';
  static const colFirstSeenTimestamp = 'first_seen_timestamp';
  static const colLastStatus = 'last_status';
  static const colLastSeenTimestamp = 'last_seen_timestamp';
  static const colLastSeenNetwork = 'last_seen_network';
  static const colLastSeenRoom = 'last_seen_room';
  static const colRoom = 'room';
  static const colNetwork = 'network';
  static const colId = 'id';
  static const colMessageId = 'message_id';
  static const colContent = 'content';
  static const colMessageTimestamp = 'message_timestamp';
  static const colDeliveryState = 'delivery_state';
  static const colAccountFirstSeenTimestamp = 'account_first_seen_timestamp';
  static const colLastActivityTimestamp = 'last_activity_timestamp';
  static const colMessageCountCached = 'message_count_cached';
  static const colCascadeId = 'cascade_id';
  static const colCreatedAt = 'created_at';
  static const colCreatedByPeerId = 'created_by_peer_id';
  static const colOriginalNetwork = 'original_network';
  static const colOriginalRoom = 'original_room';
}

class Pmdb {
  static final Map<String, Pmdb> _instances = <String, Pmdb>{};
  static Pmdb? _active;

  final String accountKey;
  Database? _database;

  Pmdb._init(this.accountKey);

  static Pmdb get instance {
    _active ??= forAccount('default');
    return _active!;
  }

  static Pmdb forAccount(String accountKey) {
    final normalized = _normalizeAccountKey(accountKey);
    return _instances.putIfAbsent(normalized, () => Pmdb._init(normalized));
  }

  static Future<Database> useAccount(String accountKey) async {
    final db = forAccount(accountKey);
    _active = db;
    return await db.db;
  }

  static Future<void> closeCurrentAccountDb() async {
    if (_active == null) {
      return;
    }

    final db = _active!;
    if (db._database != null) {
      await db._database!.close();
      db._database = null;
    }
    _active = null;
  }

  static String _normalizeAccountKey(String accountKey) {
    final trimmed = accountKey.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('accountKey must not be empty');
    }
    return trimmed;
  }

  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _openDb();
    return _database!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final accountsPath = join(dbPath, 'accounts');
    await Directory(accountsPath).create(recursive: true);
    final safeAccount = accountKey.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final path = join(accountsPath, '$safeAccount.db');

    return openDatabase(
      path,
      version: DbSchema.dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        DELETE FROM ${DbSchema.messagesTable}
        WHERE ${DbSchema.colId} NOT IN (
          SELECT MIN(${DbSchema.colId})
          FROM ${DbSchema.messagesTable}
          GROUP BY
            ${DbSchema.colNetwork},
            ${DbSchema.colRoom},
            ${DbSchema.colPeerId},
            ${DbSchema.colContent},
            ${DbSchema.colMessageTimestamp}
        )
      ''');

      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_dedup ON ${DbSchema.messagesTable} ('
        '${DbSchema.colNetwork}, ${DbSchema.colRoom}, ${DbSchema.colPeerId}, ${DbSchema.colContent}, ${DbSchema.colMessageTimestamp})',
      );
    }
  }

  Future<void> _createDb(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE ${DbSchema.accountInfoTable} (
        ${DbSchema.colPeerId} TEXT PRIMARY KEY,
        ${DbSchema.colUserName} TEXT NOT NULL,
        ${DbSchema.colRegisterTimestamp} INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbSchema.peersTable} (
        ${DbSchema.colPeerId} TEXT PRIMARY KEY,
        ${DbSchema.colUserName} TEXT NOT NULL,
        ${DbSchema.colRegisterTimestamp} INTEGER NOT NULL,
        ${DbSchema.colFirstSeenTimestamp} INTEGER NOT NULL,
        ${DbSchema.colLastStatus} TEXT NOT NULL DEFAULT 'unknown',
        ${DbSchema.colLastSeenTimestamp} INTEGER NOT NULL DEFAULT 0,
        ${DbSchema.colLastSeenNetwork} TEXT,
        ${DbSchema.colLastSeenRoom} TEXT
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbSchema.messagesTable} (
        ${DbSchema.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbSchema.colNetwork} TEXT NOT NULL,
        ${DbSchema.colRoom} TEXT NOT NULL,
        ${DbSchema.colPeerId} TEXT NOT NULL,
        ${DbSchema.colContent} TEXT NOT NULL,
        ${DbSchema.colMessageTimestamp} INTEGER NOT NULL,
        FOREIGN KEY (${DbSchema.colPeerId}) REFERENCES ${DbSchema.peersTable}(${DbSchema.colPeerId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbSchema.messageMetaTable} (
        ${DbSchema.colMessageId} INTEGER PRIMARY KEY,
        ${DbSchema.colDeliveryState} TEXT NOT NULL DEFAULT 'local',
        FOREIGN KEY (${DbSchema.colMessageId}) REFERENCES ${DbSchema.messagesTable}(${DbSchema.colId}) ON DELETE CASCADE
      )
    ''');

    batch.execute('''      
      CREATE TABLE ${DbSchema.roomsTable} (
        ${DbSchema.colNetwork} TEXT NOT NULL,
        ${DbSchema.colRoom} TEXT NOT NULL,
        ${DbSchema.colAccountFirstSeenTimestamp} INTEGER NOT NULL,
        ${DbSchema.colLastActivityTimestamp} INTEGER NOT NULL DEFAULT 0,
        ${DbSchema.colMessageCountCached} INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (${DbSchema.colNetwork}, ${DbSchema.colRoom})
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbSchema.roomMetaTable} (
        ${DbSchema.colNetwork} TEXT NOT NULL,
        ${DbSchema.colRoom} TEXT NOT NULL,
        ${DbSchema.colCreatedAt} INTEGER NOT NULL,
        ${DbSchema.colCreatedByPeerId} TEXT NOT NULL,
        PRIMARY KEY (${DbSchema.colNetwork}, ${DbSchema.colRoom})
      )
    ''');

    batch.execute('''      
      CREATE TABLE ${DbSchema.cascadesTable} (
        ${DbSchema.colCascadeId} TEXT NOT NULL,
        ${DbSchema.colNetwork} TEXT NOT NULL,
        ${DbSchema.colRoom} TEXT NOT NULL,
        PRIMARY KEY (${DbSchema.colCascadeId}, ${DbSchema.colNetwork}, ${DbSchema.colRoom})
      )
    ''');

    batch.execute('''
      CREATE TABLE ${DbSchema.cascadeMetaTable} (
        ${DbSchema.colCascadeId} TEXT PRIMARY KEY,
        ${DbSchema.colCreatedAt} INTEGER NOT NULL,
        ${DbSchema.colCreatedByPeerId} TEXT NOT NULL,
        ${DbSchema.colOriginalNetwork} TEXT,
        ${DbSchema.colOriginalRoom} TEXT
      )
    ''');

    batch.execute(
      'CREATE INDEX idx_chat_history ON ${DbSchema.messagesTable} (${DbSchema.colNetwork}, ${DbSchema.colRoom}, ${DbSchema.colMessageTimestamp} DESC)',
    );
    batch.execute(
      'CREATE UNIQUE INDEX idx_messages_dedup ON ${DbSchema.messagesTable} ('
      '${DbSchema.colNetwork}, ${DbSchema.colRoom}, ${DbSchema.colPeerId}, ${DbSchema.colContent}, ${DbSchema.colMessageTimestamp})',
    );
    batch.execute(
      'CREATE INDEX idx_messages_peer_id ON ${DbSchema.messagesTable} (${DbSchema.colPeerId})',
    );
    batch.execute(
      'CREATE INDEX idx_peers_last_seen_timestamp ON ${DbSchema.peersTable} (${DbSchema.colLastSeenTimestamp} DESC)',
    );

    await batch.commit(noResult: true);
  }
}

Future<Database> openAccountDatabase(String accountKey) async {
  return await Pmdb.useAccount(accountKey);
}

Future<void> closeCurrentAccountDatabase() async {
  await Pmdb.closeCurrentAccountDb();
}

class BaseDao {
  Future<Database> get database async => await Pmdb.instance.db;

  Future<int> create(
    String table,
    Map<String, Object?> data, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    final db = await database;
    return await db.insert(
      table,
      data,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  Future<List<Map<String, Object?>>> read(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, Object?>>> findByValue(
    String table, {
    required String column,
    required Object? value,
    bool? distinct,
    List<String>? columns,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return read(
      table,
      distinct: distinct,
      columns: columns,
      where: '$column = ?',
      whereArgs: [value],
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, Object?>>> findByValues(
    String table, {
    required String column,
    required List<Object?> values,
    bool? distinct,
    List<String>? columns,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (values.isEmpty) {
      return <Map<String, Object?>>[];
    }

    final placeholders = List.filled(values.length, '?').join(', ');
    return read(
      table,
      distinct: distinct,
      columns: columns,
      where: '$column IN ($placeholders)',
      whereArgs: values,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, Object?>>> findByColumns(
    String table, {
    required Map<String, Object?> equals,
    bool? distinct,
    List<String>? columns,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (equals.isEmpty) {
      return read(
        table,
        distinct: distinct,
        columns: columns,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    }

    final conditions = <String>[];
    final args = <Object?>[];

    for (final entry in equals.entries) {
      conditions.add('${entry.key} = ?');
      args.add(entry.value);
    }

    return read(
      table,
      distinct: distinct,
      columns: columns,
      where: conditions.join(' AND '),
      whereArgs: args,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, Object?>>> readUsingIndex(
    String table, {
    required String indexName,
    bool distinct = false,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final selectedColumns = columns == null || columns.isEmpty
        ? '*'
        : columns.join(', ');
    final whereSql = where != null && where.trim().isNotEmpty
        ? ' WHERE $where'
        : '';
    final groupBySql = groupBy != null && groupBy.trim().isNotEmpty
        ? ' GROUP BY $groupBy'
        : '';
    final havingSql = having != null && having.trim().isNotEmpty
        ? ' HAVING $having'
        : '';
    final orderBySql = orderBy != null && orderBy.trim().isNotEmpty
        ? ' ORDER BY $orderBy'
        : '';
    final limitSql = limit != null ? ' LIMIT $limit' : '';
    final offsetSql = offset != null ? ' OFFSET $offset' : '';
    final distinctSql = distinct ? 'DISTINCT ' : '';

    final sql =
        'SELECT $distinctSql$selectedColumns FROM $table INDEXED BY $indexName$whereSql$groupBySql$havingSql$orderBySql$limitSql$offsetSql';
    return db.rawQuery(sql, whereArgs);
  }

  Future<int> update(
    String table,
    Map<String, Object?> data, {
    ConflictAlgorithm? conflictAlgorithm,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      table,
      data,
      conflictAlgorithm: conflictAlgorithm,
      where: where,
      whereArgs: whereArgs,
    );
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }
}

class AccountInfoDao extends BaseDao {
  Future<int> createAccount({
    required String peerId,
    required String username,
    required int registerTimestamp,
  }) async {
    return await create(DbSchema.accountInfoTable, {
      DbSchema.colPeerId: peerId,
      DbSchema.colUserName: username,
      DbSchema.colRegisterTimestamp: registerTimestamp,
    });
  }

  Future<List<User>> readAllAccounts() async {
    final rows = await read(DbSchema.accountInfoTable);
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<User?> findAccountByPeerId(String peerId) async {
    final rows = await findByValue(
      DbSchema.accountInfoTable,
      column: DbSchema.colPeerId,
      value: peerId,
      limit: 1,
    );
    return rows.isEmpty ? null : _rowToUser(rows.first);
  }

  Future<List<User>> findAccountsByUsername(String username) async {
    final rows = await findByValue(
      DbSchema.accountInfoTable,
      column: DbSchema.colUserName,
      value: username,
    );
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<int> updateAccount({
    required String peerId,
    required String username,
    required int registerTimestamp,
  }) async {
    return await update(
      DbSchema.accountInfoTable,
      {
        DbSchema.colUserName: username,
        DbSchema.colRegisterTimestamp: registerTimestamp,
      },
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
    );
  }

  Future<int> deleteAccount(String peerId) async {
    return await delete(
      DbSchema.accountInfoTable,
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
    );
  }

  User _rowToUser(Map<String, Object?> row) {
    final ts = row[DbSchema.colRegisterTimestamp] as int?;
    return User(
      id: row[DbSchema.colPeerId] as String? ?? '',
      name: row[DbSchema.colUserName] as String? ?? '',
      registerTimestamp: ts != null ? Int64(ts) : null,
    );
  }
}

class PeersDao extends BaseDao {
  Future<int> createPeer({
    required String peerId,
    required String username,
    required int registerTimestamp,
    required int firstSeenTimestamp,
    String lastStatus = 'unknown',
    int lastSeenTimestamp = 0,
    String? lastSeenNetwork,
    String? lastSeenRoom,
  }) async {
    return await create(DbSchema.peersTable, {
      DbSchema.colPeerId: peerId,
      DbSchema.colUserName: username,
      DbSchema.colRegisterTimestamp: registerTimestamp,
      DbSchema.colFirstSeenTimestamp: firstSeenTimestamp,
      DbSchema.colLastStatus: lastStatus,
      DbSchema.colLastSeenTimestamp: lastSeenTimestamp,
      DbSchema.colLastSeenNetwork: lastSeenNetwork,
      DbSchema.colLastSeenRoom: lastSeenRoom,
    });
  }

  Future<List<User>> readAllPeers() async {
    final rows = await read(DbSchema.peersTable);
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<User?> findPeerById(String peerId) async {
    final rows = await findByValue(
      DbSchema.peersTable,
      column: DbSchema.colPeerId,
      value: peerId,
      limit: 1,
    );
    return rows.isEmpty ? null : _rowToUser(rows.first);
  }

  Future<List<User>> findPeersByIds(List<String> peerIds) async {
    final rows = await findByValues(
      DbSchema.peersTable,
      column: DbSchema.colPeerId,
      values: peerIds,
    );
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<List<User>> findPeersByUsername(String username) async {
    final rows = await findByValue(
      DbSchema.peersTable,
      column: DbSchema.colUserName,
      value: username,
    );
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<int> updatePeer({
    required String peerId,
    required String username,
    required int registerTimestamp,
    required int firstSeenTimestamp,
    String? lastStatus,
    int? lastSeenTimestamp,
    String? lastSeenNetwork,
    String? lastSeenRoom,
  }) async {
    final data = <String, Object?>{
      DbSchema.colUserName: username,
      DbSchema.colRegisterTimestamp: registerTimestamp,
      DbSchema.colFirstSeenTimestamp: firstSeenTimestamp,
    };
    if (lastStatus != null) {
      data[DbSchema.colLastStatus] = lastStatus;
    }
    if (lastSeenTimestamp != null) {
      data[DbSchema.colLastSeenTimestamp] = lastSeenTimestamp;
    }
    if (lastSeenNetwork != null) {
      data[DbSchema.colLastSeenNetwork] = lastSeenNetwork;
    }
    if (lastSeenRoom != null) {
      data[DbSchema.colLastSeenRoom] = lastSeenRoom;
    }

    return await update(
      DbSchema.peersTable,
      data,
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
    );
  }

  Future<int> touchPeerPresence({
    required String peerId,
    required int lastSeenTimestamp,
    required String lastStatus,
    String? lastSeenNetwork,
    String? lastSeenRoom,
  }) async {
    return await update(
      DbSchema.peersTable,
      {
        DbSchema.colLastSeenTimestamp: lastSeenTimestamp,
        DbSchema.colLastStatus: lastStatus,
        DbSchema.colLastSeenNetwork: lastSeenNetwork,
        DbSchema.colLastSeenRoom: lastSeenRoom,
      },
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
    );
  }

  Future<List<User>> readRecentlySeenPeers({
    required int sinceTimestamp,
    int? limit,
  }) async {
    final rows = await read(
      DbSchema.peersTable,
      where: '${DbSchema.colLastSeenTimestamp} >= ?',
      whereArgs: [sinceTimestamp],
      orderBy: '${DbSchema.colLastSeenTimestamp} DESC',
      limit: limit,
    );
    return rows.map((row) => _rowToUser(row)).toList();
  }

  Future<int> deletePeer(String peerId) async {
    return await delete(
      DbSchema.peersTable,
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
    );
  }

  User _rowToUser(Map<String, Object?> row) {
    final ts = row[DbSchema.colRegisterTimestamp] as int?;
    return User(
      id: row[DbSchema.colPeerId] as String? ?? '',
      name: row[DbSchema.colUserName] as String? ?? '',
      registerTimestamp: ts != null ? Int64(ts) : null,
    );
  }
}

class MessagesDao extends BaseDao {
  Future<int> createMessage({
    required String network,
    required String room,
    required String peerId,
    required String content,
    required int messageTimestamp,
    String deliveryState = 'local',
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final whereClause =
          '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ? AND '
          '${DbSchema.colPeerId} = ? AND ${DbSchema.colContent} = ? AND '
          '${DbSchema.colMessageTimestamp} = ?';
      final whereArgs = <Object?>[
        network,
        room,
        peerId,
        content,
        messageTimestamp,
      ];

      int messageId;
      final existingMessage = await txn.query(
        DbSchema.messagesTable,
        columns: [DbSchema.colId],
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      if (existingMessage.isNotEmpty) {
        messageId = existingMessage.first[DbSchema.colId] as int;
      } else {
        messageId = await txn.insert(DbSchema.messagesTable, {
          DbSchema.colNetwork: network,
          DbSchema.colRoom: room,
          DbSchema.colPeerId: peerId,
          DbSchema.colContent: content,
          DbSchema.colMessageTimestamp: messageTimestamp,
        });
      }

      await txn.insert(
        DbSchema.messageMetaTable,
        {
          DbSchema.colMessageId: messageId,
          DbSchema.colDeliveryState: deliveryState,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      return messageId;
    });
  }

  Future<List<ChatMessage>> readAllMessages() async {
    final rows = await read(DbSchema.messagesTable);
    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> findMessagesByPeerId(String peerId) async {
    final rows = await readUsingIndex(
      DbSchema.messagesTable,
      indexName: 'idx_messages_peer_id',
      where: '${DbSchema.colPeerId} = ?',
      whereArgs: [peerId],
      orderBy: '${DbSchema.colMessageTimestamp} DESC',
    );
    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> findMessagesByPeerIds(List<String> peerIds) async {
    final rows = await findByValues(
      DbSchema.messagesTable,
      column: DbSchema.colPeerId,
      values: peerIds,
      orderBy: '${DbSchema.colMessageTimestamp} DESC',
    );
    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> findMessagesByChat({
    required String network,
    required String room,
    int? limit,
    int? offset,
  }) async {
    final rows = await readUsingIndex(
      DbSchema.messagesTable,
      indexName: 'idx_chat_history',
      where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
      whereArgs: [network, room],
      orderBy: '${DbSchema.colMessageTimestamp} DESC',
      limit: limit,
      offset: offset,
    );
    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> readMessagesOffset({
    required String network,
    required String room,
    required int limit,
    required int offset,
  }) async {
    if (limit < 1) {
      throw ArgumentError('limit must be >= 1');
    }
    if (offset < 0) {
      throw ArgumentError('offset must be >= 0');
    }

    final rows = await readUsingIndex(
      DbSchema.messagesTable,
      indexName: 'idx_chat_history',
      where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
      whereArgs: [network, room],
      orderBy: '${DbSchema.colMessageTimestamp} DESC',
      limit: limit,
      offset: offset,
    );
    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> readLatestMessages({
    required String network,
    required String room,
    required int limit,
  }) async {
    if (limit < 1) {
      throw ArgumentError('limit must be >= 1');
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM ('
      'SELECT * FROM ${DbSchema.messagesTable} INDEXED BY idx_chat_history '
      'WHERE ${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ? '
      'ORDER BY ${DbSchema.colMessageTimestamp} DESC, ${DbSchema.colId} DESC '
      'LIMIT ?'
      ') ORDER BY ${DbSchema.colMessageTimestamp} ASC, ${DbSchema.colId} ASC',
      [network, room, limit],
    );

    return await _rowsToChatMessages(rows);
  }

  Future<List<ChatMessage>> findMessagesByChatAndPeer({
    required String network,
    required String room,
    required String peerId,
    int? limit,
    int? offset,
  }) async {
    final rows = await findByColumns(
      DbSchema.messagesTable,
      equals: {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
        DbSchema.colPeerId: peerId,
      },
      orderBy: '${DbSchema.colMessageTimestamp} DESC',
      limit: limit,
      offset: offset,
    );
    return await _rowsToChatMessages(rows);
  }

  Future<int> updateMessage({
    required int id,
    required String network,
    required String room,
    required String peerId,
    required String content,
    required int messageTimestamp,
  }) async {
    return await update(
      DbSchema.messagesTable,
      {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
        DbSchema.colPeerId: peerId,
        DbSchema.colContent: content,
        DbSchema.colMessageTimestamp: messageTimestamp,
      },
      where: '${DbSchema.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, Object?>>> findMessageMeta(int messageId) async {
    return await findByValue(
      DbSchema.messageMetaTable,
      column: DbSchema.colMessageId,
      value: messageId,
      limit: 1,
    );
  }

  Future<int> updateMessageDeliveryState({
    required int messageId,
    required String deliveryState,
  }) async {
    return await update(
      DbSchema.messageMetaTable,
      {
        DbSchema.colDeliveryState: deliveryState,
      },
      where: '${DbSchema.colMessageId} = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteMessage(int id) async {
    return await delete(
      DbSchema.messagesTable,
      where: '${DbSchema.colId} = ?',
      whereArgs: [id],
    );
  }

  Future<List<ChatMessage>> _rowsToChatMessages(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) {
      return <ChatMessage>[];
    }

    final peerIds = <String>{};
    for (final row in rows) {
      final peerId = row[DbSchema.colPeerId] as String? ?? '';
      if (peerId.isEmpty) {
        throw StateError('Message row missing peer_id: $row');
      }
      peerIds.add(peerId);
    }

    final peers = await PeersDao().findPeersByIds(peerIds.toList());
    final namesByPeerId = <String, String>{
      for (final peer in peers) peer.id: peer.name,
    };

    return rows.map((row) {
      final ts = row[DbSchema.colMessageTimestamp] as int?;
      final peerId = row[DbSchema.colPeerId] as String? ?? '';
      return ChatMessage(
        sender: User(
          id: peerId,
          name: namesByPeerId[peerId] ?? '',
          registerTimestamp: null,
        ),
        text: row[DbSchema.colContent] as String? ?? '',
        timestamp: ts != null ? Int64(ts) : null,
      );
    }).toList();
  }
}

class RoomsDao extends BaseDao {
  Future<int> createRoom({
    required String network,
    required String room,
    required int accountFirstSeenTimestamp,
    required int createdAt,
    required String createdByPeerId,
    int lastActivityTimestamp = 0,
    int messageCountCached = 0,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.insert(DbSchema.roomsTable, {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
        DbSchema.colAccountFirstSeenTimestamp: accountFirstSeenTimestamp,
        DbSchema.colLastActivityTimestamp: lastActivityTimestamp,
        DbSchema.colMessageCountCached: messageCountCached,
      });

      await txn.insert(DbSchema.roomMetaTable, {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
        DbSchema.colCreatedAt: createdAt,
        DbSchema.colCreatedByPeerId: createdByPeerId,
      });

      return 1;
    });
  }

  Future<List<Map<String, Object?>>> findRoomFirstSeen({
    required String network,
    required String room,
  }) async {
    return await findByColumns(
      DbSchema.roomsTable,
      equals: {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
      },
      limit: 1,
    );
  }

  Future<List<Map<String, Object?>>> findRoomMeta({
    required String network,
    required String room,
  }) async {
    return await findByColumns(
      DbSchema.roomMetaTable,
      equals: {
        DbSchema.colNetwork: network,
        DbSchema.colRoom: room,
      },
      limit: 1,
    );
  }

  Future<List<Map<String, Object?>>> findRoomsByNetwork({
    required String network,
  }) async {
    return await findByColumns(
      DbSchema.roomsTable,
      equals: {
        DbSchema.colNetwork: network,
      },
    );
  }

  Future<List<Map<String, Object?>>> findAllRooms() async {
    return await read(DbSchema.roomsTable);
  }

  Future<int> updateRoomMeta({
    required String network,
    required String room,
    required int accountFirstSeenTimestamp,
    required int createdAt,
    required String createdByPeerId,
    int? lastActivityTimestamp,
    int? messageCountCached,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      final membershipData = <String, Object?>{
        DbSchema.colAccountFirstSeenTimestamp: accountFirstSeenTimestamp,
      };
      if (lastActivityTimestamp != null) {
        membershipData[DbSchema.colLastActivityTimestamp] = lastActivityTimestamp;
      }
      if (messageCountCached != null) {
        membershipData[DbSchema.colMessageCountCached] = messageCountCached;
      }

      await txn.update(
        DbSchema.roomsTable,
        membershipData,
        where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
        whereArgs: [network, room],
      );

      await txn.update(
        DbSchema.roomMetaTable,
        {
          DbSchema.colCreatedAt: createdAt,
          DbSchema.colCreatedByPeerId: createdByPeerId,
        },
        where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
        whereArgs: [network, room],
      );

      return 1;
    });
  }

  Future<int> touchRoomActivity({
    required String network,
    required String room,
    required int lastActivityTimestamp,
    int? messageCountCached,
  }) async {
    final data = <String, Object?>{
      DbSchema.colLastActivityTimestamp: lastActivityTimestamp,
    };
    if (messageCountCached != null) {
      data[DbSchema.colMessageCountCached] = messageCountCached;
    }

    return await update(
      DbSchema.roomsTable,
      data,
      where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
      whereArgs: [network, room],
    );
  }

  Future<int> deleteRoom({
    required String network,
    required String room,
  }) async {
    final db = await database;
    return await db.transaction((txn) async {
      await txn.delete(
        DbSchema.roomMetaTable,
        where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
        whereArgs: [network, room],
      );
      return await txn.delete(
        DbSchema.roomsTable,
        where: '${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
        whereArgs: [network, room],
      );
    });
  }
}

class CascadesDao extends BaseDao {
  Future<void> ensureCascadeWithMeta({
    required String cascadeId,
    required String network,
    required String room,
    required int createdAt,
    required String createdByPeerId,
    String? originalNetwork,
    String? originalRoom,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        DbSchema.cascadeMetaTable,
        {
          DbSchema.colCascadeId: cascadeId,
          DbSchema.colCreatedAt: createdAt,
          DbSchema.colCreatedByPeerId: createdByPeerId,
          DbSchema.colOriginalNetwork: originalNetwork,
          DbSchema.colOriginalRoom: originalRoom,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );

      await txn.insert(
        DbSchema.cascadesTable,
        {
          DbSchema.colCascadeId: cascadeId,
          DbSchema.colNetwork: network,
          DbSchema.colRoom: room,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    });
  }

  Future<int> createCascade({
    required String cascadeId,
    required String network,
    required String room,
  }) async {
    return await create(DbSchema.cascadesTable, {
      DbSchema.colCascadeId: cascadeId,
      DbSchema.colNetwork: network,
      DbSchema.colRoom: room,
    });
  }

  Future<int> createCascadeMeta({
    required String cascadeId,
    required int createdAt,
    required String createdByPeerId,
    String? originalNetwork,
    String? originalRoom,
  }) async {
    return await create(DbSchema.cascadeMetaTable, {
      DbSchema.colCascadeId: cascadeId,
      DbSchema.colCreatedAt: createdAt,
      DbSchema.colCreatedByPeerId: createdByPeerId,
      DbSchema.colOriginalNetwork: originalNetwork,
      DbSchema.colOriginalRoom: originalRoom,
    });
  }

  Future<List<Map<String, Object?>>> findCascadeMeta(
    String cascadeId,
  ) async {
    return await findByValue(
      DbSchema.cascadeMetaTable,
      column: DbSchema.colCascadeId,
      value: cascadeId,
      limit: 1,
    );
  }

  Future<int> updateCascadeMeta({
    required String cascadeId,
    required int createdAt,
    required String createdByPeerId,
    String? originalNetwork,
    String? originalRoom,
  }) async {
    return await update(
      DbSchema.cascadeMetaTable,
      {
        DbSchema.colCreatedAt: createdAt,
        DbSchema.colCreatedByPeerId: createdByPeerId,
        DbSchema.colOriginalNetwork: originalNetwork,
        DbSchema.colOriginalRoom: originalRoom,
      },
      where: '${DbSchema.colCascadeId} = ?',
      whereArgs: [cascadeId],
    );
  }

  Future<int> deleteCascadeMeta(String cascadeId) async {
    return await delete(
      DbSchema.cascadeMetaTable,
      where: '${DbSchema.colCascadeId} = ?',
      whereArgs: [cascadeId],
    );
  }

  Future<List<Map<String, Object?>>> readCascadedRooms({
    required String cascadeId,
  }) async {
    return await findByColumns(
      DbSchema.cascadesTable,
      equals: {
        DbSchema.colCascadeId: cascadeId,
      },
    );
  }

  Future<List<Map<String, Object?>>> readCascadedRoomsAll(
    String cascadeId,
  ) async {
    return await findByValue(
      DbSchema.cascadesTable,
      column: DbSchema.colCascadeId,
      value: cascadeId,
    );
  }

  Future<List<Map<String, Object?>>> findCascadesByRoom({
    required String room,
    String? network,
  }) async {
    if (network != null && network.isNotEmpty) {
      return await findByColumns(
        DbSchema.cascadesTable,
        equals: {
          DbSchema.colNetwork: network,
          DbSchema.colRoom: room,
        },
      );
    } else {
      return await read(
        DbSchema.cascadesTable,
        where: '${DbSchema.colRoom} = ?',
        whereArgs: [room],
      );
    }
  }

  Future<int> deleteCascade({
    required String cascadeId,
    required String network,
    required String room,
  }) async {
    return await delete(
      DbSchema.cascadesTable,
      where:
          '${DbSchema.colCascadeId} = ? AND ${DbSchema.colNetwork} = ? AND ${DbSchema.colRoom} = ?',
      whereArgs: [cascadeId, network, room],
    );
  }

  Future<int> deleteCascadeAll({
    required String cascadeId,
  }) async {
    return await delete(
      DbSchema.cascadesTable,
      where: '${DbSchema.colCascadeId} = ?',
      whereArgs: [cascadeId],
    );
  }
}
