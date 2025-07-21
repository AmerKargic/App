import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class WarehouseLocalDB {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'warehouse.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shelf_labels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            barcode TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS shelf_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            shelf_barcode TEXT,
            product_id INTEGER,
            product_name TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  static Future<void> insertShelfLabel(String name, String barcode) async {
    final db = await database;
    await db.insert('shelf_labels', {
      'name': name,
      'barcode': barcode,
      'synced': 0,
    });
  }

  static Future<void> insertShelfProduct(
    String shelfBarcode,
    int productId,
    String productName,
  ) async {
    final db = await database;
    await db.insert('shelf_products', {
      'shelf_barcode': shelfBarcode,
      'product_id': productId,
      'product_name': productName,
      'synced': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedShelfLabels() async {
    final db = await database;
    return db.query('shelf_labels', where: 'synced = 0');
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedShelfProducts() async {
    final db = await database;
    return db.query('shelf_products', where: 'synced = 0');
  }

  static Future<void> markLabelAsSynced(int id) async {
    final db = await database;
    await db.update(
      'shelf_labels',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> markProductAsSynced(int id) async {
    final db = await database;
    await db.update(
      'shelf_products',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
