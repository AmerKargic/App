import 'dart:async';
import 'dart:convert';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/models/box_scan_model.dart';

class OfflineService extends ChangeNotifier {
  static final OfflineService _instance = OfflineService._internal();
  static Database? _db;

  factory OfflineService() {
    return _instance;
  }

  OfflineService._internal();
  // Add these to your OfflineService class
  bool isRouteActive = false;

  void activateRoute() {
    isRouteActive = true;
    print('Route activated');
  }

  void deactivateRoute() {
    isRouteActive = false;
    print('Route deactivated');
  }

  // Create tables for box scanning
  Future<void> _createBoxTablesIfNeeded() async {
    final db = await database;

    // Table for boxes
    await db.execute('''
    CREATE TABLE IF NOT EXISTS scanned_boxes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      oid INTEGER NOT NULL,
      box_number INTEGER NOT NULL,
      box_barcode TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      synced INTEGER DEFAULT 0,
      UNIQUE(oid, box_number)
    )
  ''');

    // Table for products in boxes
    await db.execute('''
    CREATE TABLE IF NOT EXISTS box_products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      oid INTEGER NOT NULL,
      box_number INTEGER NOT NULL,
      ean TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      synced INTEGER DEFAULT 0,
      UNIQUE(oid, box_number, ean)
    )
  ''');
  }

  // Save scanned box
  Future<void> saveScannedBox({
    required int orderId,
    required int boxNumber,
    required String boxBarcode,
    required List<Stavka> products, // Add products parameter
  }) async {
    await _createBoxTablesIfNeeded();
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    // Save the scanned box
    await db.insert('scanned_boxes', {
      'oid': orderId,
      'box_number': boxNumber,
      'box_barcode': boxBarcode,
      'timestamp': timestamp,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Save the products for this box
    for (final product in products) {
      await db.insert('box_products', {
        'oid': orderId,
        'box_number': boxNumber,
        'ean': product.ean,
        'timestamp': timestamp,
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    print("Saved box $boxNumber with ${products.length} products.");
  }

  // Save a product in a box
  Future<void> saveProductInBox({
    required int orderId,
    required int boxNumber,
    required String ean,
  }) async {
    await _createBoxTablesIfNeeded();
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    await db.insert('box_products', {
      'oid': orderId,
      'box_number': boxNumber,
      'ean': ean,
      'timestamp': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Clear products for a box
  Future<void> clearProductsInBox({
    required int orderId,
    required int boxNumber,
  }) async {
    await _createBoxTablesIfNeeded();
    final db = await database;

    await db.delete(
      'box_products',
      where: 'oid = ? AND box_number = ?',
      whereArgs: [orderId, boxNumber],
    );
  }

  // Get products for a box
  Future<List<String>> getProductsInBox({
    required int orderId,
    required int boxNumber,
  }) async {
    await _createBoxTablesIfNeeded();
    final db = await database;

    final results = await db.query(
      'box_products',
      columns: ['ean'],
      where: 'oid = ? AND box_number = ?',
      whereArgs: [orderId, boxNumber],
    );

    return results.map((row) => row['ean'] as String).toList();
  }

  // Sync boxes and products
  // Debug the syncBoxesAndProducts method in OfflineService
  Future<bool> syncBoxesAndProducts() async {
    try {
      final db = await database;

      // Get user for authentication
      final user = await SessionManager().getUser();
      if (user == null) {
        print("No user found, aborting sync.");
        return false;
      }

      // Get all unsynced boxes
      final boxes = await db.query('scanned_boxes', where: 'synced = 0');

      if (boxes.isEmpty) {
        print("No boxes to sync.");
        return true; // Nothing to sync
      }

      // Prepare data for server
      final List<Map<String, dynamic>> boxesData = [];

      for (final box in boxes) {
        final orderId = box['oid'] as int;
        final boxNumber = box['box_number'] as int;

        // Get products for this box
        final products = await getProductsInBox(
          orderId: orderId,
          boxNumber: boxNumber,
        );

        print("Box $boxNumber has ${products.length} products: $products");

        boxesData.add({
          'oid': orderId,
          'box_number': boxNumber,
          'box_barcode': box['box_barcode'],
          'timestamp': box['timestamp'],
          'products': products,
          'kup_id': user['kup_id'], // Ensure this is populated correctly
          'pos_id': user['pos_id'] ?? 0,
          'hash1': user['hash1'],
          'hash2': user['hash2'],
        });
      }

      // Debug the full JSON payload
      final payload = {'boxes': boxesData};
      print("Payload being sent to server: ${jsonEncode(payload)}");

      // Send to server
      final response = await http.post(
        Uri.parse('${DriverApiService.baseUrl}/sync_boxes.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print("Server response: ${response.body}");

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // Delete synced boxes and products from the local database
          for (final box in boxes) {
            final orderId = box['oid'] as int;
            final boxNumber = box['box_number'] as int;

            // Delete products for this box
            await db.delete(
              'box_products',
              where: 'oid = ? AND box_number = ?',
              whereArgs: [orderId, boxNumber],
            );

            // Delete the box itself
            await db.delete(
              'scanned_boxes',
              where: 'id = ?',
              whereArgs: [box['id']],
            );
          }

          print(
            "Successfully cleared synced boxes and products from the local database.",
          );
          return true;
        }
      }

      return false;
    } catch (e) {
      print("Error syncing boxes and products: $e");
      return false;
    }
  }

  // Initialize database
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await openDatabase(
      join(await getDatabasesPath(), 'digitalis_offline.db'),
      version: 2,
      onCreate: (db, version) async {
        // Activity logs table
        await db.execute('''
          CREATE TABLE activity_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            timestamp TEXT NOT NULL,
            type_id INTEGER NOT NULL,
            related_id INTEGER,
            text TEXT,
            data TEXT,
            latitude REAL,
            longitude REAL,
            synced INTEGER DEFAULT 0
          )
        ''');

        // Orders table for offline access
        await db.execute('''
          CREATE TABLE offline_orders (
            id INTEGER PRIMARY KEY,
            data TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');

        // Scanned boxes table
        await db.execute('''
          CREATE TABLE scanned_boxes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            oid INTEGER NOT NULL,
            box_number INTEGER NOT NULL, 
            box_barcode TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            UNIQUE(oid, box_barcode)
          )
        ''');

        // Shelf system tables - importing from warehouse_local_db.dart
        await db.execute('''
          CREATE TABLE shelf_labels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            barcode TEXT,
            synced INTEGER DEFAULT 0,
            UNIQUE(barcode)
          )
        ''');

        await db.execute('''
          CREATE TABLE shelf_products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            shelf_barcode TEXT,
            product_id INTEGER,
            product_name TEXT,
            synced INTEGER DEFAULT 0,
            UNIQUE(shelf_barcode, product_id)
          )
        ''');

        // Wishstock changes table for retail/komercijalist
        await db.execute('''
          CREATE TABLE wishstock_changes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            aid INTEGER NOT NULL,
            kup_id INTEGER NOT NULL,
            pos_id INTEGER NOT NULL,
            new_value REAL NOT NULL,
            timestamp TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            UNIQUE(aid, kup_id, pos_id)
          )
        ''');

        // Create box scan tables
        await _createBoxScanTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // For users upgrading from old versions
        if (oldVersion < 2) {
          await _createBoxScanTables(db);
        }
      },
    );
    return _db!;
  }

  // Create box scan tables
  Future<void> _createBoxScanTables(Database db) async {
    // Box scans table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS box_scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oid INTEGER NOT NULL,
        box_number INTEGER NOT NULL,
        box_barcode TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        UNIQUE(oid, box_number)
      )
    ''');

    // Box products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS box_products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        oid INTEGER NOT NULL,
        box_number INTEGER NOT NULL,
        ean TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  //databas se for saving location realtime
  Future<void> _createLocationTableIfNeeded() async {
    final db = await database;

    await db.execute('''
    CREATE TABLE IF NOT EXISTS user_locations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude REAL,
      longitude REAL,
      timestamp TEXT,
      synced INTEGER DEFAULT 0
    )
  ''');
  }

  Future<void> saveLocation(double latitude, double longitude) async {
    print(' LOCATION SAVE CALLED FROM:');
    print(StackTrace.current.toString().split('\n').take(15).join('\n'));
    print(' END STACK TRACE');

    await _createLocationTableIfNeeded();
    final db = await database;
    final timestamp = DateTime.now().toIso8601String();

    await db.insert('user_locations', {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'synced': 0,
    });
  }

  Future<void> syncLocations(
    List<Map<String, dynamic>> unsyncedLocations,
  ) async {
    print('🔄 syncLocations called with ${unsyncedLocations.length} locations');

    final session = SessionManager();
    final user = await session.getUser();

    if (user == null) {
      print('❌ No user found, aborting sync');
      return;
    }

    final data = {
      'kup_id': user['kup_id'],
      'hash1': user['hash1'],
      'hash2': user['hash2'],
      'locations': unsyncedLocations,
    };

    try {
      final requestBody = jsonEncode(data);
      print('📦 Request bwdy: $requestBody'); // Log the request body
      print(
        '📤 Sending request to: https://10.0.2.2/appinternal/api/save_location.php',
      );

      final response = await http.post(
        Uri.parse('http://10.0.2.2/appinternal/api/save_location.php'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print('📥 Response body: ${response.body}');

      print('📦 Request bodwy: ${jsonEncode(data)}');
      print('📥 Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == 1) {
          // ✅ STEP 1: Mark locations as synced
          final db = await database;
          for (final location in unsyncedLocations) {
            await db.update(
              'user_locations',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [location['id']],
            );
          }
          print('✅ Marked ${unsyncedLocations.length} locations as synced');

          // ✅ STEP 2: Delete all synced data
          await _deleteSyncedLogs();
        } else {
          print('❌ Server returned error: ${result['message']}');
        }
      }
    } catch (e) {
      print('❌ Error syncing locations: $e');
    }
  }

  // Log activity with automatic sync attempt
  Future<void> logActivity({
    required int typeId,
    required String description,
    int? relatedId,
    String? text,
    Map<String, dynamic>? extraData,
  }) async {
    print('➡️ Starting logActivity: $description');

    try {
      final db = await database;
      print('✅ Got database connection');

      final user = await SessionManager().getUser();
      print('User data: ${user != null ? 'found' : 'null'}');

      if (user == null) {
        print('❌ No user found, aborting logActivity');
        return;
      }

      final userId = user['kup_id'];
      final timestamp = DateTime.now().toIso8601String();

      // Fetch the current location
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        print('❌ Failed to get location: $e');
      }

      final latitude = position?.latitude;
      final longitude = position?.longitude;

      print(
        '📝 Inserting activity: typeId=$typeId, userId=$userId, latitude=$latitude, longitude=$longitude',
      );

      // Insert into database
      final id = await db.insert('activity_logs', {
        'user_id': userId,
        'timestamp': timestamp,
        'type_id': typeId,
        'related_id': relatedId,
        'text': text ?? description,
        'data': extraData != null ? jsonEncode(extraData) : null,
        'latitude': latitude,
        'longitude': longitude,
        'synced': 0,
      });

      print('✅ Activity inserted with ID: $id');

      // Try to sync immediately if online
      _trySyncActivities();
    } catch (e, stack) {
      print('❌ Error in logActivity: $e');
      print('Stack trace: $stack');
    }
  }

  // Save order for offline access
  Future<void> saveOrder(int orderId, Map<String, dynamic> orderData) async {
    final db = await database;
    await db.insert('offline_orders', {
      'id': orderId,
      'data': jsonEncode(orderData),
      'timestamp': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Get saved order
  Future<Map<String, dynamic>?> getOrder(int orderId) async {
    final db = await database;
    final result = await db.query(
      'offline_orders',
      where: 'id = ?',
      whereArgs: [orderId],
    );

    if (result.isNotEmpty) {
      try {
        return jsonDecode(result.first['data'] as String);
      } catch (e) {
        debugPrint('Error decoding order data: $e');
      }
    }
    return null;
  }

  // Save shelf label
  Future<void> saveShelfLabel({
    required String name,
    required String barcode,
  }) async {
    final db = await database;
    await db.insert('shelf_labels', {
      'name': name,
      'barcode': barcode,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Save shelf product
  Future<void> saveShelfProduct({
    required String shelfBarcode,
    required int productId,
    required String productName,
  }) async {
    final db = await database;
    await db.insert('shelf_products', {
      'shelf_barcode': shelfBarcode,
      'product_id': productId,
      'product_name': productName,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Save wishstock change
  Future<void> saveWishstockChange({
    required int aid,
    required int kupId,
    required int posId,
    required double newValue,
  }) async {
    final db = await database;
    await db.insert('wishstock_changes', {
      'aid': aid,
      'kup_id': kupId,
      'pos_id': posId,
      'new_value': newValue,
      'timestamp': DateTime.now().toIso8601String(),
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Try to sync activities
  // Replace your current _trySyncActivities method with this version:
  // Update the _trySyncActivities method to prepare data correctly:
  Future<void> _trySyncActivities() async {
    print('🔄 Starting sync attempt');

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('📵 No internet connection, skipping sync');
      return;
    }

    print('🌐 Online, continuing with sync');

    try {
      final db = await database;
      final logs = await db.query('activity_logs', where: 'synced = 0');

      print('📊 Found ${logs.length} logs to sync');
      if (logs.isEmpty) return;

      // Get user for auth
      final user = await SessionManager().getUser();
      if (user == null) {
        print('❌ No user found, aborting sync');
        return;
      }

      print('👤 Got user: ${user['kup_id']}');

      // Prepare logs for sync - UPDATED FORMAT
      final logsForSync = logs.map((log) {
        // Parse stored JSON
        final Map<String, dynamic> extraDataMap = log['data'] != null
            ? jsonDecode(log['data'].toString())
            : null;

        return {
          'local_id': log['id'],
          'komerc_id': log['user_id'],
          'date_report': log['timestamp'],
          'type_id': log['type_id'],
          'text': log['text'],
          'oid_id': log['related_id'],
          'extra_data': log['data'],
          'latitude': log['latitude'],
          'longitude': log['longitude'],
        };
      }).toList();

      print('📤 Sending ${logsForSync.length} logs to server');
      print('📍 Server URL: http://10.0.2.2/appinternal/api/sync_logs.php');

      final requestBody = jsonEncode({
        'kup_id': user['kup_id'].toString(),
        'pos_id': user['pos_id'] != null
            ? user['pos_id'].toString()
            : "0", // Always include pos_id
        'hash1': user['hash1'],
        'hash2': user['hash2'],
        'logs': logsForSync,
      });

      print('📦 Request body: $requestBody');

      // Send to server
      final response = await http.post(
        Uri.parse('http://10.0.2.2/appinternal/api/sync_logs.php'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      print('📥 Response status code: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final result = jsonDecode(response.body);
          print('🔍 Decoded response: $result');

          // Check success using the format your API returns (boolean false, not 0)
          if (result['success'] == true) {
            // Mark synced logs
            for (final log in logs) {
              await db.update(
                'activity_logs',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [log['id']],
              );
            }
            print('✅ Successfully synced ${logs.length} logs');
            await _deleteSyncedLogs();
          } else {
            print(
              '❌ Server returned error: ${result['message'] ?? 'Unknown error'}',
            );
          }
        } catch (e) {
          print('❌ Error parsing response: $e');
        }
      } else {
        print('❌ Server returned non-200 status code: ${response.statusCode}');
      }
    } catch (e, stack) {
      print('❌ Sync error: $e');
      print('Stack trace: $stack');
    }
  }

  Future<void> _deleteSyncedLogs() async {
    try {
      final db = await database;

      // Delete all synced activity logs
      final deletedLogs = await db.delete('activity_logs', where: 'synced = 1');
      print('🗑️ DELETED $deletedLogs synced activity logs');

      // Delete all synced box scans and their products
      final syncedBoxes = await db.query('box_scans', where: 'synced = 1');
      for (final box in syncedBoxes) {
        // Delete products first
        await db.delete(
          'box_products',
          where: 'oid = ? AND box_number = ?',
          whereArgs: [box['oid'], box['box_number']],
        );
      }
      final deletedBoxes = await db.delete('box_scans', where: 'synced = 1');
      print('🗑️ DELETED $deletedBoxes synced box scans');

      // Delete all synced locations
      final deletedLocations = await db.delete(
        'user_locations',
        where: 'synced = 1',
      );
      print('🗑️ DELETED $deletedLocations synced locations');

      // Delete all synced shelf data
      final deletedShelfLabels = await db.delete(
        'shelf_labels',
        where: 'synced = 1',
      );
      final deletedShelfProducts = await db.delete(
        'shelf_products',
        where: 'synced = 1',
      );
      print(
        '🗑️ DELETED $deletedShelfLabels shelf labels, $deletedShelfProducts shelf products',
      );

      // Delete all synced wishstock changes
      final deletedWishstock = await db.delete(
        'wishstock_changes',
        where: 'synced = 1',
      );
      print('🗑️ DELETED $deletedWishstock wishstock changes');

      print('🧹 Cleanup complete - all synced data deleted');
    } catch (e) {
      print('❌ Error deleting synced data: $e');
    }
  }

  // Sync scanned boxes
  Future<void> _syncScannedBoxes(Map<String, dynamic> user) async {
    try {
      final db = await database;
      final boxes = await db.query('scanned_boxes', where: 'synced = 0');

      if (boxes.isEmpty) return;

      // Prepare boxes for sync
      final boxesForSync = boxes.map((box) {
        return {
          'local_id': box['id'],
          'oid': box['oid'],
          'box_number': box['box_number'],
          'box_barcode': box['box_barcode'],
        };
      }).toList();

      // Send to server - use driver_scan_box.php endpoint
      for (final box in boxesForSync) {
        final response = await http.post(
          Uri.parse('http://10.0.2.2/appinternal/api/driver_scan_box.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'code': box['box_barcode'],
            'oid': box['oid'].toString(),
            'kup_id': user['kup_id'].toString(),
            'hash1': user['hash1'],
            'hash2': user['hash2'],
          }),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == 1) {
            // Mark box as synced
            await db.update(
              'scanned_boxes',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [box['local_id']],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing scanned boxes: $e');
    }
  }

  // Sync shelf labels and products
  Future<void> _syncShelfData(Map<String, dynamic> user) async {
    try {
      final db = await database;

      // Sync shelf labels
      final labels = await db.query('shelf_labels', where: 'synced = 0');
      for (final label in labels) {
        final response = await http.post(
          Uri.parse('http://10.0.2.2/appinternal/api/add_shelf.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'shelf_name': label['name'].toString(),
            'shelf_ean': label['barcode'].toString(),
            'kup_id': user['kup_id'].toString(),
            'hash1': user['hash1'],
            'hash2': user['hash2'],
          }),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == 1) {
            await db.update(
              'shelf_labels',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [label['id']],
            );
          }
        }
      }

      // Sync shelf products
      final products = await db.query('shelf_products', where: 'synced = 0');
      for (final product in products) {
        final response = await http.post(
          Uri.parse(
            'http://10.0.2.2/appinternal/api/add_products_to_shelf.php',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'shelf_barcode': product['shelf_barcode'].toString(),
            'product_ids': jsonEncode([product['product_id']]),
            'kup_id': user['kup_id'].toString(),
            'hash1': user['hash1'],
            'hash2': user['hash2'],
          }),
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == 1) {
            await db.update(
              'shelf_products',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [product['id']],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing shelf data: $e');
    }
  }

  // Sync wishstock changes
  Future<void> _syncWishstockChanges(Map<String, dynamic> user) async {
    try {
      final db = await database;
      final changes = await db.query('wishstock_changes', where: 'synced = 0');

      for (final change in changes) {
        final response = await http.post(
          Uri.parse('http://10.0.2.2/appinternal/api/save_wishstock.php'),
          body: {
            'aid': change['aid'].toString(),
            'kup_id': change['kup_id'].toString(),
            'pos_id': change['pos_id'].toString(),
            'stock_wish': change['new_value'].toString(),
            'hash1': user['hash1'],
            'hash2': user['hash2'],
          },
        );

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == 1) {
            await db.update(
              'wishstock_changes',
              {'synced': 1},
              where: 'id = ?',
              whereArgs: [change['id']],
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing wishstock changes: $e');
    }
  }

  // Manually trigger sync
  Future<bool> syncNow() async {
    try {
      await _trySyncActivities();
      return true;
    } catch (e) {
      debugPrint('Manual sync error: $e');
      return false;
    }
  }

  // Clean up old data
  Future<void> cleanupOldData() async {
    try {
      // Just delete all synced data - no time-based cleanup needed
      await _deleteSyncedLogs();

      // Only keep time-based cleanup for orders since they don't have synced flag
      final db = await database;
      final orderCutoffDate = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final deletedOrders = await db.delete(
        'offline_orders',
        where: 'timestamp < ?',
        whereArgs: [orderCutoffDate],
      );
      print('🗑️ DELETED $deletedOrders old orders');
    } catch (e) {
      debugPrint('Database cleanup error: $e');
    }
  }

  // Activity types as static constants
  static const int DRIVER_SCAN = 7; // DELIVERY_START
  static const int DRIVER_IN_TRANSIT = 8; // DELIVERY_IN_TRANSIT
  static const int DRIVER_DELIVERY = 9; // DELIVERY_END
  static const int RETAIL_ACCEPTED = 10; // DELIVERY_ACCEPTED
  static const int WAREHOUSE_PRODUCT = 3; // ORDER_SCAN_AID
  static const int WAREHOUSE_ORDER = 5; // ORDER_SCAN
  static const int WAREHOUSE_COMPLETE = 6; // ORDER_END
  static const int WAREHOUSE_SHELF = 12; // SHELF_CREATE
  static const int RETAIL_WISHSTOCK = 14; // WISHSTOCK_CHANGE

  // Save box scan with products
  Future<void> saveBoxScan(BoxScan boxScan) async {
    final db = await database;

    await db.transaction((txn) async {
      // Save box scan
      await txn.insert(
        'box_scans',
        boxScan.toDbMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Save products
      if (boxScan.products.isNotEmpty) {
        // Clear existing products for this box
        await txn.delete(
          'box_products',
          where: 'oid = ? AND box_number = ?',
          whereArgs: [boxScan.oid, boxScan.boxNumber],
        );

        // Insert new products
        for (final ean in boxScan.products) {
          await txn.insert('box_products', {
            'oid': boxScan.oid,
            'box_number': boxScan.boxNumber,
            'ean': ean,
            'timestamp': boxScan.timestamp,
          });
        }
      }
    });

    // Try to sync immediately if online
    _trySyncBoxes();
  }

  // Get box scans for an order
  Future<List<BoxScan>> getBoxScansForOrder(int oid) async {
    final db = await database;

    // Get boxes
    final boxes = await db.query(
      'box_scans',
      where: 'oid = ?',
      whereArgs: [oid],
    );

    // Get products for each box and build BoxScan objects
    return Future.wait(
      boxes.map((box) async {
        final products = await db.query(
          'box_products',
          where: 'oid = ? AND box_number = ?',
          whereArgs: [box['oid'], box['box_number']],
          columns: ['ean'],
        );

        final eans = products.map((p) => p['ean'] as String).toList();

        return BoxScan.fromDbMap(box, eans);
      }),
    );
  }

  // Sync boxes to server
  Future<void> _trySyncBoxes() async {
    print('🔄 Starting box sync');

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('📵 No internet connection, skipping box sync');
      return;
    }

    try {
      final db = await database;

      // Get unsynced boxes
      final boxes = await db.query('box_scans', where: 'synced = 0');

      print('📊 Found ${boxes.length} unsynced boxes');
      if (boxes.isEmpty) return;

      // Get user for auth
      final user = await SessionManager().getUser();
      if (user == null) {
        print('❌ No user found, aborting sync');
        return;
      }

      // Prepare boxes with products
      final boxesToSync = await Future.wait(
        boxes.map((box) async {
          final products = await db.query(
            'box_products',
            where: 'oid = ? AND box_number = ?',
            whereArgs: [box['oid'], box['box_number']],
          );

          final eans = products.map((p) => p['ean'] as String).toList();

          return {
            'oid': box['oid'],
            'box_number': box['box_number'],
            'box_barcode': box['box_barcode'],
            'timestamp': box['timestamp'],
            'products': eans,
          };
        }),
      );

      print('📤 Sending ${boxesToSync.length} boxes to server');

      // Send to server
      final response = await http.post(
        Uri.parse('http://10.0.2.2/appinternal/api/sync_boxes.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'kup_id': user['kup_id'].toString(),
          'pos_id': user['pos_id'] != null ? user['pos_id'].toString() : "0",
          'hash1': user['hash1'],
          'hash2': user['hash2'],
          'boxes': boxesToSync,
        }),
      );

      print('📥 Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          // Mark boxes as synced
          for (final box in boxes) {
            await db.update(
              'box_scans',
              {'synced': 1},
              where: 'oid = ? AND box_number = ?',
              whereArgs: [box['oid'], box['box_number']],
            );
          }
          print('✅ Synced ${boxes.length} boxes successfully');
          await _deleteSyncedLogs(); // Clean up synced logs
        } else {
          print('❌ Server returned error: ${result['message']}');
        }
      }
    } catch (e) {
      print('❌ Box sync error: $e');
    }
  }

  // Start periodic location tracking
  //timer set for a minute
  void startLocationTracking() {
    print('🔄 Starting location tracking');

    Timer.periodic(const Duration(minutes: 5), (_) async {
      if (isRouteActive) {
        print('📍 Saving location');
        final position = await Geolocator.getCurrentPosition();
        await saveLocation(position.latitude, position.longitude);
      } else {
        print('🚫 Route is not active, skipping location save');
      }
    });

    Timer.periodic(const Duration(minutes: 15), (_) async {
      print('🔄 Syncing locations');
      final db = await database;
      final unsyncedLocations = await db.query(
        'user_locations',
        where: 'synced = 0',
      );
      print('📊 Unsynced locations: $unsyncedLocations');
      await syncLocations(unsyncedLocations);
    });
  }

  // Add this to your periodic sync method
  Future<void> syncAll() async {
    await _trySyncActivities(); // Your existing sync method
    await _trySyncBoxes(); // Add this line to also sync boxes
  }
}
