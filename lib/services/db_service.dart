import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/app_log.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'mi_unbootloader_logs.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT,
            message TEXT,
            type TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertLog(AppLog log) async {
    final db = await database;
    return await db.insert('logs', log.toMap());
  }

  Future<List<AppLog>> getLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'logs',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return AppLog.fromMap(maps[i]);
    });
  }

  Future<void> clearLogs() async {
    final db = await database;
    await db.delete('logs');
  }
}
