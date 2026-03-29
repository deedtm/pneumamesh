import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class GlobalDbSchema {
  static const String dbFileName = 'pneumamesh_global.db';

  static const String accountsTable = 'accounts';

  static const String colId = 'id';
  static const String colUsername = 'username';
  static const String colPrivateKey = 'private_key';
}

class GlobalDb {
  static final GlobalDb instance = GlobalDb._init();
  static Database? _database;

  GlobalDb._init();

  Future<Database> get db async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, GlobalDbSchema.dbFileName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE ${GlobalDbSchema.accountsTable} (
            ${GlobalDbSchema.colId} INTEGER PRIMARY KEY AUTOINCREMENT,
            ${GlobalDbSchema.colUsername} TEXT UNIQUE NOT NULL,
            ${GlobalDbSchema.colPrivateKey} TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<Map<String, dynamic>?> getAccount(String username) async {
    final database = await instance.db;
    final res = await database.query(
      GlobalDbSchema.accountsTable,
      where: '${GlobalDbSchema.colUsername} = ?',
      whereArgs: [username],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> createAccount(String username, String privateKey) async {
    final database = await instance.db;
    await database.insert(GlobalDbSchema.accountsTable, {
      GlobalDbSchema.colUsername: username,
      GlobalDbSchema.colPrivateKey: privateKey,
    });
  }
}
