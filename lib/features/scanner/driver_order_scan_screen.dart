// Replace your entire driver_order_scan_screen.dart with this:

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:digitalisapp/features/maps/delivery_route_manager.dart';
import 'package:digitalisapp/features/maps/multi_stop_navigation_screen.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/models/offline_status_widget.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:digitalisapp/widgets/bulk_scanner_dialog.dart';
import 'package:digitalisapp/widgets/phone_call_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverOrderScanScreen extends StatefulWidget {
  const DriverOrderScanScreen({super.key});

  @override
  State<DriverOrderScanScreen> createState() => _DriverOrderScanScreenState();
}

class _DriverOrderScanScreenState extends State<DriverOrderScanScreen> {
  final DeliveryRouteManager _routeManager = DeliveryRouteManager();
  final OfflineService _offlineService = OfflineService();

  // 🔥 BULK SCANNING VARIABLES
  Map<int, List<String>> _bulkScanQueue =
      {}; // orderId -> list of scanned codes
  Map<int, int> _expectedBoxCounts = {}; // orderId -> expected box count
  bool _bulkScanMode = false;
  int? _currentBulkOrderId;
  Timer? _bulkScanTimer;

  // 🔥 EXISTING VARIABLES
  Map<int, Set<int>> _scannedBoxesByOrder = {};
  Map<int, bool> _acceptedOrders = {};
  Map<int, Set<int>> _discardedBoxes = {};
  Map<int, Set<int>> _missingBoxes = {}; // Track boxes marked as missing

  String statusMessage = '';
  bool loading = false;
  final Set<int> _expandedOrders = {};

  @override
  void initState() {
    super.initState();
    setState(() {});
  }

  // 🔥 SMART INDIVIDUAL SCANNING WITH PREDICTION
  Future<void> smartIndividualScan(String code) async {
    print('🔍 DEBUG: smartIndividualScan called with: "$code"'); // DEBUG
    if (code.toLowerCase().startsWith('blag')) {
      final resp = await DriverApiService.getDocumentsByDoc(code);
      if (resp['success'] == 1 && resp['documents'] != null) {
        addOrdersFromBlag(List<Map<String, dynamic>>.from(resp['documents']));
        setState(() {
          statusMessage =
              "✅ Dodano ${resp['documents'].length} narudžbi sa blag dokumenta!";
        });
        return;
      } else {
        setState(() {
          statusMessage =
              resp['message'] ?? "Greška pri dohvaćanju narudžbi sa blaga!";
        });
        return;
      }
    }
    RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
    final match = regex.firstMatch(code);

    print('🔍 DEBUG: Regex match result: $match'); // DEBUG

    if (match == null) {
      print('🔥 DEBUG: Regex failed for code: "$code"'); // DEBUG
      setState(() => statusMessage = "❌ Invalid barcode format: $code");
      return;
    }

    final boxNumber = int.parse(match.group(1)!);
    final oid = int.parse(match.group(2)!);

    print('🔍 DEBUG: Parsed - Box: $boxNumber, Order: $oid'); // DEBUG
    await _offlineService.saveScannedBox(
      orderId: oid,
      boxNumber: boxNumber,
      boxBarcode: code,
      products: [], // Add products if needed
    );
    // 🔥 CONFLICT CHECK FIRST
    final conflictResponse = await DriverApiService.checkConflict(
      oid,
      boxNumber,
    );
    if (conflictResponse['success'] == 1 &&
        conflictResponse['conflict'] == true) {
      _showConflictDialog(
        oid,
        boxNumber,
        conflictResponse['conflict_driver'] ?? 'Unknown driver',
      );
      return;
    }

    // Check if we have this order already
    final existingOrder = _routeManager.allStops
        .where((stop) => stop.order.oid == oid)
        .firstOrNull;

    if (existingOrder == null) {
      // New order - fetch and start individual scanning
      await _startIndividualScanForOrder(oid, code);
    } else {
      // Continue individual scanning for existing order
      await _addToIndividualScan(oid, code);
    }
  }

  void processOrder(DriverOrder order, String firstCode) async {
    // Only add to route manager - don't process the box here
    await _routeManager.addStop(order);

    // Initialize tracking maps
    _scannedBoxesByOrder[order.oid] ??= {};
    _discardedBoxes[order.oid] ??= {};
    _missingBoxes[order.oid] ??= {};

    setState(() {});
  }

  Future<void> _startIndividualScanForOrder(int oid, String firstCode) async {
    setState(() {
      loading = true;
      statusMessage = 'Loading order information...';
    });

    try {
      final orderResponse = await DriverApiService.fetchOrder(firstCode);

      if (orderResponse['success'] == 1 && orderResponse['order'] != null) {
        final fetchedOrder = DriverOrder.fromJson(orderResponse['order']);

        // Save order locally
        await _offlineService.saveOrder(
          fetchedOrder.oid,
          orderResponse['order'],
        );

        // Initialize individual scanning
        setState(() {
          _expectedBoxCounts[oid] = fetchedOrder.brojKutija;
          loading = false;
          statusMessage =
              "📦 Individual scan: Box 1/${fetchedOrder.brojKutija} scanned";
        });

        // 🔥 ADD THIS: Process the order in route manager (this was missing!)
        processOrder(fetchedOrder, firstCode);

        // Process the first box
        await _processSingleBox(oid, firstCode);
      } else {
        setState(() {
          loading = false;
          statusMessage = orderResponse['message'] ?? 'Error loading order';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        statusMessage = 'Error: ${e.toString()}';
      });
    }
  }

  // Add this helper method to your class:
  List<Color> _getProgressBarColors(
    int scannedCount,
    int discardedCount,
    int missingCount,
    int totalBoxes,
  ) {
    final progress =
        (scannedCount + discardedCount + missingCount) / totalBoxes;

    if (progress >= 1.0) {
      return [Colors.green, Colors.green.shade300];
    } else if (progress >= 0.7) {
      return [Colors.blue, Colors.blue.shade300];
    } else if (progress >= 0.4) {
      return [Colors.amber, Colors.amber.shade300];
    } else {
      return [Colors.purple, Colors.purple.shade300];
    }
  }

  Color _getOrderBorderColor(
    DriverOrder order,
    int scannedCount,
    int discardedCount,
    int missingCount,
    bool isAccepted,
  ) {
    if (isAccepted) {
      return Colors.orange; // Accepted and ready for delivery
    }

    final totalProcessed = scannedCount + discardedCount + missingCount;
    final progress = totalProcessed / order.brojKutija;

    if (progress >= 1.0) {
      return Colors.green; // Complete - ready to accept
    } else if (progress >= 0.7) {
      return Colors.blue; // Mostly complete
    } else if (progress >= 0.4) {
      return Colors.amber; // In progress
    } else if (scannedCount > 0) {
      return Colors.purple; // Started scanning
    } else {
      return Colors.grey.shade300; // Not started
    }
  }

  double _getOrderBorderWidth(
    DriverOrder order,
    int scannedCount,
    int discardedCount,
    int missingCount,
    bool isAccepted,
  ) {
    if (isAccepted) {
      return 3.0; // Thick border for accepted orders
    }

    final totalProcessed = scannedCount + discardedCount + missingCount;
    final progress = totalProcessed / order.brojKutija;

    if (progress >= 1.0) {
      return 2.5; // Ready to accept
    } else if (progress >= 0.5) {
      return 2.0; // Good progress
    } else {
      return 1.0; // Normal border
    }
  }

  LinearGradient? _getOrderGradient(
    DriverOrder order,
    int scannedCount,
    int discardedCount,
    int missingCount,
    bool isAccepted,
  ) {
    if (isAccepted) {
      // Orange gradient for accepted orders
      return LinearGradient(
        colors: [Colors.orange.shade50, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final totalProcessed = scannedCount + discardedCount + missingCount;
    final progress = totalProcessed / order.brojKutija;

    if (progress >= 1.0) {
      // Green gradient for complete orders
      return LinearGradient(
        colors: [Colors.green.shade50, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (progress >= 0.7) {
      // Blue gradient for mostly complete
      return LinearGradient(
        colors: [Colors.blue.shade50, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (progress >= 0.4) {
      // Amber gradient for in progress
      return LinearGradient(
        colors: [Colors.amber.shade50, Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    return null; // Default white background
  }

  Future<void> _addToIndividualScan(int oid, String code) async {
    final boxNumber = _extractBoxNumber(code);

    print('🔍 DEBUG: Adding box $boxNumber to order $oid'); // DEBUG

    // Check if already scanned
    if (_scannedBoxesByOrder[oid]?.contains(boxNumber) == true) {
      setState(() => statusMessage = "⚠️ Box $boxNumber already scanned!");
      HapticFeedback.lightImpact();
      return;
    }

    // Check if discarded
    if (_discardedBoxes[oid]?.contains(boxNumber) == true) {
      setState(
        () => statusMessage = "❌ Box $boxNumber was discarded due to conflict",
      );
      return;
    }

    // 🔥 DODAJ OVU PROVJERU - možda se boxovi ne dodaju u mapu
    if (!_scannedBoxesByOrder.containsKey(oid)) {
      _scannedBoxesByOrder[oid] = <int>{}; // Ensure the set exists
    }

    print(
      '🔍 DEBUG: Before scanning - scanned boxes for $oid: ${_scannedBoxesByOrder[oid]}',
    ); // DEBUG

    await _processSingleBox(oid, code);

    print(
      '🔍 DEBUG: After _processSingleBox - scanned boxes for $oid: ${_scannedBoxesByOrder[oid]}',
    ); // DEBUG

    final scannedCount = _scannedBoxesByOrder[oid]?.length ?? 0;
    final expectedCount = _expectedBoxCounts[oid] ?? 0;

    setState(() {
      statusMessage =
          "📦 Individual scan: Box $scannedCount/$expectedCount scanned";
    });

    // 🔥 SUCCESS FEEDBACK
    if (scannedCount >= expectedCount) {
      HapticFeedback.heavyImpact();
      setState(() {
        statusMessage = "✅ All boxes scanned! Order ready for acceptance.";
      });
    } else {
      HapticFeedback.lightImpact();
    }
  }

  // 🔥 BULK SCANNING MODE
  void startBulkScanMode() {
    setState(() {
      statusMessage = "🔥 Starting bulk scan mode...";
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BulkScannerDialog(
        onBarcodesScanned: (List<String> codes) {
          _processBulkScannedCodes(codes);
        },
        onCancel: () {
          setState(() {
            statusMessage = "Bulk scan cancelled";
          });
        },
      ),
    );
  }

  void addOrdersFromBlag(List<Map<String, dynamic>> docs) async {
    for (final doc in docs) {
      final order = DriverOrder.fromJson({
        'oid': doc['oid_id'] ?? doc['z_oid'] ?? 0,
        'broj': doc['Dokument_ID'] ?? '',
        'kupac': doc['Kupac'] ?? {},
        'stavke': doc['stavke'] ?? [],
        'iznos': doc['OrderSummary']?['iznos'] ?? 0,
        'broj_kutija': doc['OrderSummary']?['br_kutija'] ?? 0,
        'napomena': doc['blg_Napomena'] ?? '',
        'napomena_vozac': doc['OrderSummary']?['nap_vozac'] ?? '',
      });
      await _routeManager.addStop(order);
      _scannedBoxesByOrder[order.oid] ??= {};
      _discardedBoxes[order.oid] ??= {};
      _missingBoxes[order.oid] ??= {};
      _expectedBoxCounts[order.oid] = order.brojKutija;
    }
    setState(() {});
  }

  Future<void> _processBulkScannedCodes(List<String> codes) async {
    setState(() {
      loading = true;
      statusMessage = 'Processing ${codes.length} scanned codes...';
    });

    Map<int, List<String>> codesByOrder = {};
    List<String> invalidCodes = [];
    List<Map<String, dynamic>> conflictDetails = [];

    // Group codes by order ID and check conflicts
    for (String code in codes) {
      RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
      final match = regex.firstMatch(code);

      if (match != null) {
        final boxNumber = int.parse(match.group(1)!);
        final oid = int.parse(match.group(2)!);

        // 🔥 ENHANCED CONFLICT CHECK
        final conflictResponse = await DriverApiService.checkConflict(
          oid,
          boxNumber,
        );

        if (conflictResponse['success'] == 1 &&
            conflictResponse['conflict'] == true) {
          conflictDetails.add({
            'code': code,
            'box_number': boxNumber,
            'order_id': oid,
            'conflict_driver':
                conflictResponse['conflict_driver'] ?? 'Unknown driver',
          });
          continue;
        }

        // No conflict - add to processing queue
        if (!codesByOrder.containsKey(oid)) {
          codesByOrder[oid] = [];
        }
        codesByOrder[oid]!.add(code);
      } else {
        invalidCodes.add(code);
      }
    }

    // 🔥 PROCES VALID CODES - OVO JE NEDOSTAJALO!
    int totalProcessed = 0;

    for (int orderId in codesByOrder.keys) {
      final orderCodes = codesByOrder[orderId]!;

      print(
        '🔍 BULK DEBUG: Processing ${orderCodes.length} codes for order $orderId',
      );

      // Check if we have this order already
      final existingOrder = _routeManager.allStops
          .where((stop) => stop.order.oid == orderId)
          .firstOrNull;

      if (existingOrder == null) {
        // 🔥 NEW ORDER - fetch it first using the first code
        print('🔍 BULK DEBUG: Fetching new order $orderId');

        try {
          final orderResponse = await DriverApiService.fetchOrder(
            orderCodes[0],
          );

          if (orderResponse['success'] == 1 && orderResponse['order'] != null) {
            final fetchedOrder = DriverOrder.fromJson(orderResponse['order']);

            // Save order locally
            await _offlineService.saveOrder(
              fetchedOrder.oid,
              orderResponse['order'],
            );

            // Initialize tracking
            setState(() {
              _expectedBoxCounts[orderId] = fetchedOrder.brojKutija;
            });

            // Add to route manager
            processOrder(fetchedOrder, orderCodes[0]);

            print('🔍 BULK DEBUG: Order $orderId fetched and added');
          }
        } catch (e) {
          print('🔥 BULK DEBUG: Error fetching order $orderId: $e');
          continue; // Skip this order if can't fetch
        }
      }

      // 🔥 PROCESS ALL CODES FOR THIS ORDER
      for (String code in orderCodes) {
        try {
          print('🔍 BULK DEBUG: Processing code $code for order $orderId');

          final boxNumber = _extractBoxNumber(code);

          // Check if already scanned
          if (_scannedBoxesByOrder[orderId]?.contains(boxNumber) == true) {
            print('🔍 BULK DEBUG: Box $boxNumber already scanned, skipping');
            continue;
          }

          // 🔥 PROCESS THE BOX - OVO JE KLJUČNO!
          await _processSingleBox(orderId, code);
          totalProcessed++;

          print(
            '🔍 BULK DEBUG: Processed box $boxNumber for order $orderId. Total processed: $totalProcessed',
          );
        } catch (e) {
          print('🔥 BULK DEBUG: Error processing code $code: $e');
        }
      }
    }

    // 🔥 SHOW DETAILED RESULTS
    setState(() {
      loading = false;
      statusMessage = _buildBulkScanResults(
        totalProcessed,
        conflictDetails,
        invalidCodes,
      );
    });

    // 🔥 SHOW CONFLICT DIALOG IF ANY CONFLICTS
    if (conflictDetails.isNotEmpty) {
      _showBulkConflictDialog(conflictDetails);
    }
  }

  // 🔥 NEW: Build detailed results message
  String _buildBulkScanResults(
    int processed,
    List<Map<String, dynamic>> conflicts,
    List<String> invalid,
  ) {
    List<String> results = [];

    results.add("🚀 Bulk scan complete!");
    results.add("✅ Processed: $processed boxes");

    if (conflicts.isNotEmpty) {
      results.add("❌ Conflicts: ${conflicts.length}");
      // Show first few conflicts
      for (int i = 0; i < conflicts.length && i < 3; i++) {
        final conflict = conflicts[i];
        results.add(
          "   📦 Box ${conflict['box_number']} → ${conflict['conflict_driver']}",
        );
      }
      if (conflicts.length > 3) {
        results.add("   ... and ${conflicts.length - 3} more");
      }
    }

    if (invalid.isNotEmpty) {
      results.add("⚠️ Invalid: ${invalid.length}");
    }

    return results.join("\n");
  }

  // 🔥 NEW: Show bulk conflict dialog
  void _showBulkConflictDialog(List<Map<String, dynamic>> conflicts) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Conflicts Detected!'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${conflicts.length} boxes have conflicts:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: conflicts.length,
                  itemBuilder: (context, index) {
                    final conflict = conflicts[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${conflict['order_id']} - Box ${conflict['box_number']}',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.red),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Scanned by: ${conflict['conflict_driver']}',
                                  style: TextStyle(color: Colors.red.shade800),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  // 🔥 SHARED BOX PROCESSING
  Future<void> _processSingleBox(int oid, String code) async {
    final boxNumber = _extractBoxNumber(code);

    print('🔍 DEBUG: Processing single box $boxNumber for order $oid'); // DEBUG

    try {
      final response = await DriverApiService.scanBox(code, oid);

      print('🔍 DEBUG: Scan response: $response'); // DEBUG

      if (response['success'] == 1) {
        // 🔥 ENSURE THE SET EXISTS
        if (!_scannedBoxesByOrder.containsKey(oid)) {
          _scannedBoxesByOrder[oid] = <int>{};
        }

        // Only add if not already added
        if (!_scannedBoxesByOrder[oid]!.contains(boxNumber)) {
          _scannedBoxesByOrder[oid]!.add(boxNumber);

          print(
            '🔍 DEBUG: Added box $boxNumber to scanned list. Total: ${_scannedBoxesByOrder[oid]?.length}',
          ); // DEBUG

          // Save scanned box locally
          await _offlineService.saveScannedBox(
            orderId: oid,
            boxNumber: boxNumber,
            boxBarcode: code,
            products: [], // Add products if needed
          );

          // Log activity
          await _offlineService.logActivity(
            typeId: OfflineService.DRIVER_SCAN,
            description: 'Scanned box',
            relatedId: oid,
            extraData: {'box_number': boxNumber, 'box_code': code},
          );

          // 🔥 FORCE UI UPDATE
          setState(() {});
        } else {
          print(
            '🔍 DEBUG: Box $boxNumber already exists in scanned list',
          ); // DEBUG
        }
      } else {
        print(
          '🔥 DEBUG: Failed to scan box $boxNumber: ${response['message']}',
        ); // DEBUG
        setState(() {
          statusMessage =
              "❌ Failed to scan box $boxNumber: ${response['message']}";
        });
      }
    } catch (e) {
      print('🔥 DEBUG: Error processing box $boxNumber: $e'); // DEBUG
      setState(() {
        statusMessage = "❌ Error scanning box $boxNumber: $e";
      });
    }
  }

  // 🔥 CONFLICT HANDLING
  void _showConflictDialog(int orderId, int boxNumber, String conflictDriver) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('CONFLICT!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Box #$boxNumber from order #$orderId is already scanned by:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    conflictDriver,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text('❌ This order cannot be processed due to conflicts.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                statusMessage =
                    "❌ Order #$orderId skipped due to conflicts. Scan a different order.";
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Skip Order'),
          ),
        ],
      ),
    );
  }

  int _getOrderIdFromPhoneNumber(String phoneNumber) {
    // Find the order that has this phone number
    for (final stop in _routeManager.allStops) {
      if (stop.order.kupac.telefon == phoneNumber) {
        return stop.order.oid;
      }
    }
    return 0; // fallback
  }

  Future<void> _callCustomer(String phoneNumber, String customerName) async {
    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // Show confirmation dialog
    final shouldCall = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.phone, color: Colors.blue),
            SizedBox(width: 8),
            Text('Call Customer?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Call $customerName?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    phoneNumber,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 16),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'This will open your phone app',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.phone, size: 18),
            label: Text('Call Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (shouldCall == true) {
      try {
        final Uri phoneUri = Uri.parse('tel:$cleanPhone');

        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);

          // Log the call activity
          await _offlineService.logActivity(
            typeId:
                OfflineService.DRIVER_SCAN, // or create a new type for calls
            description: 'Called customer',
            relatedId: _getOrderIdFromPhoneNumber(
              phoneNumber,
            ), // You'll need this helper
            extraData: {
              'phone_number': phoneNumber,
              'customer_name': customerName,
              'call_time': DateTime.now().toIso8601String(),
            },
          );

          // Show success message
          setState(() {
            statusMessage = "📞 Calling $customerName...";
          });

          // Clear message after 3 seconds
          Timer(Duration(seconds: 3), () {
            if (mounted) {
              setState(() => statusMessage = "");
            }
          });
        } else {
          // Show error if can't launch phone app
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Cannot open phone app'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Handle any errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error calling: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 🔥 PROBLEM DETECTION
  String _detectOrderProblems(DriverOrder order) {
    List<String> problems = [];

    // Address problems
    if (order.kupac.adresa.length < 10) {
      problems.add("⚠️ Short address - may be unclear");
    }

    if (order.kupac.adresa.toLowerCase().contains('bb') ||
        order.kupac.adresa.toLowerCase().contains('b.b.')) {
      problems.add("⚠️ Address contains 'bb' - no house number");
    }

    // Payment problems
    if (order.iznos > 500) {
      problems.add(
        "💰 High value delivery (${order.iznos.toStringAsFixed(2)} KM)",
      );
    }

    if (order.trebaVratitiNovac) {
      problems.add(
        "💸 Cash return required (${order.iznos.abs().toStringAsFixed(2)} KM)",
      );
    }

    // Large delivery
    if (order.brojKutija > 5) {
      problems.add(
        "📦 Large delivery (${order.brojKutija} boxes) - call customer ahead",
      );
    }

    // Special notes
    if (order.napomenaVozac.isNotEmpty) {
      problems.add("🚨 Driver note: ${order.napomenaVozac}");
    }

    return problems.isEmpty ? "✅ No issues detected" : problems.join("\n");
  }

  // 🔥 MISSING BOXES HANDLER
  void _handleMissingBoxes(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Missing Boxes?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are there boxes missing for Order #$orderId?'),
            SizedBox(height: 12),
            Text(
              'This will record the missing boxes and skip this order for now.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _recordMissingBoxes(orderId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('Report Missing'),
          ),
        ],
      ),
    );
  }

  void _recordMissingBoxes(int orderId) async {
    final scannedCount = _scannedBoxesByOrder[orderId]?.length ?? 0;
    final expectedCount = _expectedBoxCounts[orderId] ?? 0;
    final missingCount = expectedCount - scannedCount;

    // Record missing boxes
    _missingBoxes[orderId] ??= {};
    for (int i = 1; i <= expectedCount; i++) {
      if (!_scannedBoxesByOrder[orderId]!.contains(i)) {
        _missingBoxes[orderId]!.add(i);
      }
    }

    // Log the missing boxes
    await _offlineService.logActivity(
      typeId: OfflineService.DRIVER_SCAN,
      description: 'Missing boxes reported',
      relatedId: orderId,
      extraData: {
        'missing_boxes': _missingBoxes[orderId]!.toList(),
        'missing_count': missingCount,
        'scanned_count': scannedCount,
        'expected_count': expectedCount,
      },
    );

    setState(() {
      statusMessage =
          "📝 Recorded $missingCount missing boxes for Order #$orderId";
    });
  }

  // 🔥 ACCEPTANCE LOGIC
  bool _canAcceptOrder(int orderId) {
    final order = _routeManager.allStops
        .where((stop) => stop.order.oid == orderId)
        .firstOrNull
        ?.order;

    if (order == null) return false;

    final scannedCount = _scannedBoxesByOrder[orderId]?.length ?? 0;
    final discardedCount = _discardedBoxes[orderId]?.length ?? 0;
    final missingCount = _missingBoxes[orderId]?.length ?? 0;

    // Can accept if all boxes are accounted for (scanned + discarded + missing = total)
    return (scannedCount + discardedCount + missingCount) >= order.brojKutija;
  }

  // 🔥 UTILITY METHODS
  int _extractBoxNumber(String code) {
    RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
    final match = regex.firstMatch(code);
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    // Fallback to old method
    final parts = code.toLowerCase().split('ku');
    if (parts.length >= 2) {
      final boxPart = parts[1].split(RegExp(r'[^0-9]'))[0];
      return int.tryParse(boxPart) ?? 0;
    }
    return 0;
  }

  // 🔥 EXISTING METHODS (acceptOrder, completeOrder, etc.)
  void acceptOrder(int orderId) async {
    if (_acceptedOrders[orderId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Order #$orderId already accepted.")),
      );
      return;
    }

    setState(() {
      loading = true;
      statusMessage = 'Accepting order #$orderId...';
    });

    try {
      final response = await DriverApiService.acceptOrder(orderId);

      if (response['success'] == 1) {
        setState(() {
          _acceptedOrders[orderId] = true;
          loading = false;
          statusMessage = "✅ Order #$orderId accepted.";
        });
      } else {
        setState(() {
          loading = false;
          statusMessage = '❌ ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        statusMessage = '❌ Error: ${e.toString()}';
      });
    }
  }

  // Replace your completeOrder function with this fixed version:
  Future<void> completeOrder(int orderId) async {
    setState(() {
      loading = true;
      statusMessage = 'Completing order #$orderId...';
    });

    try {
      // 🔥 FIXED: Use the correct API method
      final response = await DriverApiService.completeOrder(orderId);

      print('🔍 DEBUG: Complete response: $response');

      if (response['success'] == 1) {
        // 🔥 ALWAYS REMOVE COMPLETED ORDERS FROM UI
        _routeManager.removeStop(orderId);
        _scannedBoxesByOrder.remove(orderId);
        _acceptedOrders.remove(orderId);
        _discardedBoxes.remove(orderId);
        _missingBoxes.remove(orderId);
        _expectedBoxCounts.remove(orderId);

        await _offlineService.logActivity(
          typeId: OfflineService.DRIVER_DELIVERY,
          description: 'Order completed and removed',
          relatedId: orderId,
          extraData: {
            'oid': orderId,
            'action': 'delivery_completed',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        setState(() {
          loading = false;
          statusMessage = '✅ Order #$orderId completed and removed';
        });
      } else {
        setState(() {
          loading = false;
          statusMessage = '❌ ${response['message']}';
        });
      }

      // Clear status message after 3 seconds
      Timer(Duration(seconds: 3), () {
        if (mounted) {
          setState(() => statusMessage = "");
        }
      });
    } catch (e) {
      setState(() {
        loading = false;
        statusMessage = '❌ Error completing order: ${e.toString()}';
      });

      Timer(Duration(seconds: 3), () {
        if (mounted) {
          setState(() => statusMessage = "");
        }
      });
    }
  }

  // Replace your existing removeOrder function with this enhanced version:
  // Replace your removeOrder function with this fixed version:
  void removeOrder(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Order?'),
        content: Text(
          'Are you sure you want to remove order #$orderId from route?\n\nThis will cancel the order in the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              setState(() {
                loading = true;
                statusMessage = 'Cancelling order #$orderId...';
              });

              try {
                // 🔥 REMOVED: Don't check local _acceptedOrders anymore!
                // 🔥 ALWAYS try to cancel - let the API/database decide
                print('🔍 DEBUG: Attempting to cancel order $orderId');

                final response = await DriverApiService.cancelOrder(orderId);

                print('🔍 DEBUG: Cancel response: $response');

                if (response['success'] == 1) {
                  print('🔍 DEBUG: Order was accepted and now cancelled');

                  await _offlineService.logActivity(
                    typeId: OfflineService.DRIVER_SCAN,
                    description: 'Order cancelled and removed',
                    relatedId: orderId,
                    extraData: {
                      'action': 'cancel_and_remove',
                      'reason': 'manually_removed',
                      'timestamp': DateTime.now().toIso8601String(),
                    },
                  );

                  setState(() {
                    statusMessage = '✅ Order #$orderId cancelled successfully';
                  });
                } else if (response['message'].contains('statusu') ||
                    response['message'].contains('prihvaćena') ||
                    response['message'].contains('tranzitu')) {
                  // Order wasn't in cancellable status - that's fine, just remove locally
                  print(
                    '🔍 DEBUG: Order not in cancellable status, removing locally',
                  );

                  setState(() {
                    statusMessage = '✅ Order #$orderId removed from route';
                  });
                } else {
                  print('🔍 DEBUG: Cancel failed: ${response['message']}');

                  setState(() {
                    statusMessage =
                        '⚠️ ${response['message']} - Order removed locally';
                  });
                }

                // 🔥 ALWAYS remove from local data structures
                _routeManager.removeStop(orderId);
                _scannedBoxesByOrder.remove(orderId);
                _acceptedOrders.remove(orderId);
                _discardedBoxes.remove(orderId);
                _missingBoxes.remove(orderId);
                _expectedBoxCounts.remove(orderId);

                setState(() {
                  loading = false;
                });

                Timer(Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() => statusMessage = "");
                  }
                });
              } catch (e) {
                print('🔍 DEBUG: Exception in removeOrder: $e');

                setState(() {
                  loading = false;
                  statusMessage =
                      '⚠️ Error: ${e.toString()} - Order removed locally';
                });

                // Remove locally anyway
                _routeManager.removeStop(orderId);
                _scannedBoxesByOrder.remove(orderId);
                _acceptedOrders.remove(orderId);
                _discardedBoxes.remove(orderId);
                _missingBoxes.remove(orderId);
                _expectedBoxCounts.remove(orderId);

                setState(() {});

                Timer(Duration(seconds: 3), () {
                  if (mounted) {
                    setState(() => statusMessage = "");
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Remove & Cancel'),
          ),
        ],
      ),
    );
  }

  void clearAllOrders() {
    if (_routeManager.stopCount == 0) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear All?'),
        content: Text('Are you sure you want to remove all orders from route?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _routeManager.clearStops();
              _scannedBoxesByOrder.clear();
              _acceptedOrders.clear();
              _discardedBoxes.clear();
              _missingBoxes.clear();
              _expectedBoxCounts.clear();
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void startMultiStopNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MultiStopNavigationScreen()),
    );
  }

  // ...existing code...
  // ...existing code...
  // ...existing code...
  Future<String?> _openScannerAndGetCode({required int oid}) async {
    try {
      // Determine next unscanned box
      final scanned = _scannedBoxesByOrder[oid] ?? <int>{};
      final discarded = _discardedBoxes[oid] ?? <int>{};
      final stop = _routeManager.allStops
          .where((s) => s.order.oid == oid)
          .firstOrNull;
      final total = _expectedBoxCounts[oid] ?? (stop?.order.brojKutija ?? 1);

      int nextBox = 1;
      for (int i = 1; i <= total; i++) {
        if (!scanned.contains(i) && !discarded.contains(i)) {
          nextBox = i;
          break;
        }
      }

      return await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) {
            bool armed = false;
            return StatefulBuilder(
              builder: (ctx, setLocalState) => Scaffold(
                appBar: AppBar(
                  title: const Text('Potvrdite skeniranjem kutije'),
                  backgroundColor: Colors.blue,
                  actions: [
                    // DEBUG: real KU{box}KU{oid} for this order
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, 'KU${nextBox}KU$oid'),
                      child: const Text(
                        'DEBUG auto',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    // DEBUG: your fixed test code
                    TextButton(
                      onPressed: () => Navigator.pop(context, 'KU1KU2348487'),
                      child: const Text(
                        'DEBUG fixed',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                body: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Skenirajte bilo koju kutiju ove narudžbe (#$oid)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            armed
                                ? 'Spreman za skeniranje…'
                                : 'Pritisnite “Skeniraj kutiju” pa usmjerite kameru u barkod.',
                            style: TextStyle(color: Colors.blue.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Predloženi kod: KU...',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: MobileScanner(
                        onDetect: (capture) {
                          if (!armed) return;
                          final barcodes = capture.barcodes;
                          if (barcodes.isEmpty) return;
                          final code = barcodes.first.rawValue ?? '';
                          setLocalState(() => armed = false);
                          Navigator.pop(context, code);
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.center_focus_strong),
                              label: const Text('Skeniraj kutiju'),
                              onPressed: () {
                                setLocalState(() => armed = true);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ciljaj kod i skeniraj...'),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // DEBUG: same as real scan (auto code)
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context, 'KU${nextBox}KU$oid'),
                            child: const Text('DEBUG auto'),
                          ),
                          const SizedBox(width: 8),
                          // DEBUG: fixed test code you asked for
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(context, 'KU1KU2348487'),
                            child: const Text('DEBUG fixed'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } catch (_) {
      return null;
    }
  }
  // ...existing code...
  // ...existing code...

  // ...existing code...
  // ...existing code...
  Future<void> _scanBeforeComplete(int oid) async {
    final code = await _openScannerAndGetCode(oid: oid);
    if (!mounted || code == null || code.isEmpty) return;

    // Validate KU{box}KU{oid}
    final re = RegExp(r'^KU(\d+)KU(\d+)$', caseSensitive: false);
    final m = re.firstMatch(code.trim());
    if (m == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Neispravan barkod')));
      return;
    }
    final scannedOid = int.tryParse(m.group(2) ?? '0') ?? 0;
    if (scannedOid != oid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skenirani OID $scannedOid ne odgovara narudžbi #$oid'),
        ),
      );
      return;
    }

    // Record this scan like normal
    try {
      final resp = await DriverApiService.scanBoxx(code, oid);
      if (mounted && (resp['message'] is String)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(resp['message'] as String)));
      }
    } catch (_) {}

    await completeOrder(oid);
  }
  // ...existing code...

  @override
  Widget build(BuildContext context) {
    final allStops = _routeManager.allStops;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _bulkScanMode
              ? "Bulk Scanning Order #$_currentBulkOrderId"
              : "Package Scanner",
        ),
        backgroundColor: _bulkScanMode ? Colors.orange : null,
        actions: [
          if (allStops.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: clearAllOrders,
              tooltip: 'Clear all orders',
            ),
        ],
      ),
      body: Column(
        children: [
          // Offline status widget
          OfflineStatusWidget(
            onSyncPressed: () {
              _offlineService.syncNow().then((success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? "Sync successful!" : "Sync failed"),
                  ),
                );
              });
            },
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Scanning section
                  HardwareBarcodeInput(
                    hintText: "Scan package barcode...",
                    onBarcodeScanned: (code) {
                      print('🔍 Hardware scan received: $code');
                      smartIndividualScan(code);
                    },
                  ),

                  // Scan mode buttons
                  Column(
                    children: [
                      // Prvi red - 4 dugmeta
                      const SizedBox(height: 8),
                      // Drugi red - 3 dugmeta
                      // ...existing code...
                      Row(
                        children: [
                          // DEBUG dugme umjesto Box 5
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => smartIndividualScan("BLAG17635"),
                              icon: Icon(Icons.bug_report, color: Colors.white),
                              label: Text(
                                "DEBUG BLAG",
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => smartIndividualScan("BLAG17635"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown,
                              ),
                              child: Text(
                                "Box 6",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  smartIndividualScan("KU1KU2348487"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange,
                              ),
                              child: Text(
                                "Box 7",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ...existing
                      const SizedBox(height: 8),
                      // Treći red - BULK SCAN
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: startBulkScanMode,
                              icon: Icon(Icons.qr_code_scanner),
                              label: Text("🔥 BULK SCAN"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Status message
                  if (statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        statusMessage,
                        style: GoogleFonts.inter(
                          color: statusMessage.startsWith('✅')
                              ? Colors.green
                              : statusMessage.startsWith('❗') ||
                                    statusMessage.startsWith('⚠️')
                              ? Colors.orange
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Navigation button
                  if (allStops.any(
                    (stop) => _acceptedOrders[stop.order.oid] == true,
                  )) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Delivery Route: ${allStops.where((stop) => _acceptedOrders[stop.order.oid] == true).length} accepted orders",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: startMultiStopNavigation,
                            icon: Icon(Icons.navigation),
                            label: Text("START NAVIGATION"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Orders list
                  const SizedBox(height: 16),
                  Expanded(
                    child: allStops.isEmpty
                        ? Center(
                            child: Text(
                              "No scanned orders.\nScan a barcode to add an order.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: allStops.length,
                            itemBuilder: (context, index) {
                              final stop = allStops[index];
                              final order = stop.order;
                              final scannedCount =
                                  _scannedBoxesByOrder[order.oid]?.length ?? 0;
                              final discardedCount =
                                  _discardedBoxes[order.oid]?.length ?? 0;
                              final missingCount =
                                  _missingBoxes[order.oid]?.length ?? 0;
                              final totalProcessed =
                                  scannedCount + discardedCount + missingCount;
                              final isComplete =
                                  totalProcessed >= order.brojKutija;
                              final isAccepted =
                                  _acceptedOrders[order.oid] == true;
                              final canAccept = _canAcceptOrder(order.oid);
                              final isExpanded = _expandedOrders.contains(
                                order.oid,
                              );

                              // ADD THIS: safe retail detection (works even if the model doesn't expose flags)
                              final bool isRetailOrder = (() {
                                try {
                                  final dynamic d = order;
                                  final dynamic k = order.kupac;
                                  return d?.isMaloprodaja == true ||
                                      k?.isMaloprodaja == true ||
                                      d?.meta?['is_maloprodaja'] == 1 ||
                                      d?.extra?['is_maloprodaja'] == 1;
                                } catch (_) {
                                  return false;
                                }
                              })();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: _getOrderBorderColor(
                                      order,
                                      scannedCount,
                                      discardedCount,
                                      missingCount,
                                      isAccepted,
                                    ),
                                    width: _getOrderBorderWidth(
                                      order,
                                      scannedCount,
                                      discardedCount,
                                      missingCount,
                                      isAccepted,
                                    ),
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: _getOrderGradient(
                                      order,
                                      scannedCount,
                                      discardedCount,
                                      missingCount,
                                      isAccepted,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (_expandedOrders.contains(
                                          order.oid,
                                        )) {
                                          _expandedOrders.remove(order.oid);
                                        } else {
                                          _expandedOrders.add(order.oid);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Header row
                                          Row(
                                            children: [
                                              Icon(
                                                isAccepted
                                                    ? Icons.directions_car
                                                    : isComplete
                                                    ? Icons.check_circle
                                                    : Icons.local_shipping,
                                                color: isAccepted
                                                    ? Colors.orange
                                                    : isComplete
                                                    ? Colors.green
                                                    : Colors.blue,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      "Order #${order.oid}",
                                                      style: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                    Text(
                                                      "👤 ${order.broj.toString()} \n${order.kupac.naziv}",
                                                      style:
                                                          GoogleFonts.inter(),
                                                      maxLines: isExpanded
                                                          ? null
                                                          : 1,
                                                      overflow: isExpanded
                                                          ? null
                                                          : TextOverflow
                                                                .ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  isExpanded
                                                      ? Icons.expand_less
                                                      : Icons.expand_more,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    if (_expandedOrders
                                                        .contains(order.oid)) {
                                                      _expandedOrders.remove(
                                                        order.oid,
                                                      );
                                                    } else {
                                                      _expandedOrders.add(
                                                        order.oid,
                                                      );
                                                    }
                                                  });
                                                },
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () =>
                                                    removeOrder(order.oid),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            height: 4,
                                            margin: EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              color: Colors.grey.shade200,
                                            ),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: order.brojKutija > 0
                                                  ? ((scannedCount +
                                                                discardedCount +
                                                                missingCount) /
                                                            order.brojKutija)
                                                        .clamp(0.0, 1.0)
                                                  : 0.0,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  gradient: LinearGradient(
                                                    colors:
                                                        _getProgressBarColors(
                                                          scannedCount,
                                                          discardedCount,
                                                          missingCount,
                                                          order.brojKutija,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Problem detection
                                          Container(
                                            margin: EdgeInsets.only(top: 8),
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color:
                                                  _detectOrderProblems(
                                                    order,
                                                  ).startsWith("✅")
                                                  ? Colors.green.shade50
                                                  : Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color:
                                                    _detectOrderProblems(
                                                      order,
                                                    ).startsWith("✅")
                                                    ? Colors.green.shade200
                                                    : Colors.amber.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              _detectOrderProblems(order),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    _detectOrderProblems(
                                                      order,
                                                    ).startsWith("✅")
                                                    ? Colors.green.shade800
                                                    : Colors.amber.shade800,
                                              ),
                                            ),
                                          ),

                                          // Status indicators
                                          if (isAccepted)
                                            Container(
                                              margin: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.orange.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.gps_fixed,
                                                    color: Colors.orange,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Order accepted - ready for navigation",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          if (missingCount > 0)
                                            Container(
                                              margin: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.orange.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.help_outline,
                                                    color: Colors.orange,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Missing boxes: $missingCount (reported)",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          if (discardedCount > 0)
                                            Container(
                                              margin: EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.red.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.warning,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      "Discarded boxes: $discardedCount (conflicts)",
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color:
                                                            Colors.red.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Expanded content
                                          if (isExpanded) ...[
                                            Divider(),
                                            Text("📍 ${order.kupac.adresa}"),
                                            if (order
                                                .kupac
                                                .phoneNumbers
                                                .isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              PhoneCallWidget(
                                                kupac: order.kupac,
                                              ),
                                            ] else ...[
                                              // Show no phone available message
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                  horizontal: 12,
                                                ),
                                                margin: EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone_disabled,
                                                      color: Colors.grey,
                                                      size: 18,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'No phone number available',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            if (order.kupac.email.isNotEmpty)
                                              Text("📧 ${order.kupac.email}"),
                                            if (order.napomena.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  "📝 Note: ${order.napomena}",
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            if (order.napomenaVozac.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Text(
                                                  "🚨 Driver: ${order.napomenaVozac}",
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),

                                            // 🔥 ADDED: Order Items Display
                                            if (order.stavke.isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              Container(
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blue.shade200,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.inventory_2,
                                                          color: Colors
                                                              .blue
                                                              .shade700,
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 6),
                                                        Text(
                                                          "Order Items (${order.stavke.length})",
                                                          style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors
                                                                .blue
                                                                .shade800,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ...order.stavke
                                                        .take(5)
                                                        .map(
                                                          (item) => Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  bottom: 4,
                                                                ),
                                                            child: Row(
                                                              children: [
                                                                Container(
                                                                  width: 24,
                                                                  height: 24,
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .blue
                                                                        .shade100,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Center(
                                                                    child: Text(
                                                                      '${item.kol.toInt()}',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .blue
                                                                            .shade800,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 8,
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    item.naziv,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                          .grey
                                                                          .shade800,
                                                                    ),
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "${item.cijena.toStringAsFixed(2)} KM",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color: Colors
                                                                        .green
                                                                        .shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    if (order.stavke.length > 5)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              top: 4,
                                                            ),
                                                        child: Text(
                                                          "... and ${order.stavke.length - 5} more items",
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],

                                            const SizedBox(height: 8),
                                          ],

                                          // Payment info
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 6,
                                              horizontal: isExpanded ? 8 : 0,
                                            ),
                                            margin: EdgeInsets.only(
                                              top: isExpanded ? 4 : 0,
                                            ),
                                            decoration: isExpanded
                                                ? BoxDecoration(
                                                    color:
                                                        order.trebaVratitiNovac
                                                        ? Colors.red.shade50
                                                        : order.iznos > 0
                                                        ? Colors.green.shade50
                                                        : Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  )
                                                : null,
                                            child: Text(
                                              order.iznos > 0
                                                  ? "💰 Collect: ${order.iznos.toStringAsFixed(2)} KM"
                                                  : order.trebaVratitiNovac
                                                  ? "↩️ Return: ${order.iznos.abs().toStringAsFixed(2)} KM"
                                                  : "✅ No payment",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: order.trebaVratitiNovac
                                                    ? Colors.red
                                                    : order.iznos > 0
                                                    ? Colors.green.shade800
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),

                                          // Box count and actions
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    "📦 Total: ${order.brojKutija} boxes",
                                                    style: GoogleFonts.inter(
                                                      color:
                                                          Colors.grey.shade700,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    "✅ Scanned: $scannedCount boxes",
                                                    style: GoogleFonts.inter(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  if (missingCount > 0)
                                                    Text(
                                                      "❓ Missing: $missingCount boxes",
                                                      style: GoogleFonts.inter(
                                                        color: Colors.orange,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  if (discardedCount > 0)
                                                    Text(
                                                      "❌ Discarded: $discardedCount boxes",
                                                      style: GoogleFonts.inter(
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Column(
                                                children: [
                                                  // Accept/Complete button
                                                  ElevatedButton(
                                                    onPressed: isAccepted
                                                        ? () async {
                                                            // Scan again before completing
                                                            await _scanBeforeComplete(
                                                              order.oid,
                                                            );
                                                          }
                                                        : canAccept
                                                        ? () => acceptOrder(
                                                            order.oid,
                                                          )
                                                        : null,
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              isAccepted
                                                              ? Colors.orange
                                                              : canAccept
                                                              ? Colors.green
                                                              : Colors.grey,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: Text(
                                                      isAccepted
                                                          ? "Complete"
                                                          : canAccept
                                                          ? "Accept Order"
                                                          : "Scan all boxes",
                                                    ),
                                                  ),

                                                  //  if (isRetailOrder &&
                                                  //    !isAccepted) ...[
                                                  const SizedBox(height: 6),
                                                  ElevatedButton.icon(
                                                    icon: const Icon(
                                                      Icons.store,
                                                    ),
                                                    label: const Text(
                                                      'Predaj maloprodaji',
                                                    ),
                                                    onPressed: () async {
                                                      final resp =
                                                          await DriverApiService.requestRetailApproval(
                                                            order.oid,
                                                          );
                                                      final msg =
                                                          resp['message'] ??
                                                          'Zahtjev poslan';
                                                      if (!context.mounted)
                                                        return;
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(msg),
                                                        ),
                                                      );
                                                    },
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.indigo,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                  ),

                                                  //],
                                                  const SizedBox(height: 4),

                                                  // Action buttons row
                                                  Row(
                                                    children: [
                                                      if (!isComplete &&
                                                          !isAccepted) ...[
                                                        // Show next box to scan
                                                        ElevatedButton.icon(
                                                          onPressed: () {
                                                            // Calculate next box number
                                                            final scannedBoxes =
                                                                _scannedBoxesByOrder[order
                                                                    .oid] ??
                                                                {};
                                                            final discardedBoxes =
                                                                _discardedBoxes[order
                                                                    .oid] ??
                                                                {};
                                                            int nextBox = 1;

                                                            for (
                                                              int i = 1;
                                                              i <=
                                                                  order
                                                                      .brojKutija;
                                                              i++
                                                            ) {
                                                              if (!scannedBoxes
                                                                      .contains(
                                                                        i,
                                                                      ) &&
                                                                  !discardedBoxes
                                                                      .contains(
                                                                        i,
                                                                      )) {
                                                                nextBox = i;
                                                                break;
                                                              }
                                                            }

                                                            // 🔥 CAMERA SCAN umjesto direktnog poziva
                                                            Navigator.push(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder: (context) => Scaffold(
                                                                  appBar: AppBar(
                                                                    title: Text(
                                                                      'Scan Box #$nextBox for Order #${order.oid}',
                                                                    ),
                                                                    backgroundColor:
                                                                        Colors
                                                                            .blue,
                                                                  ),
                                                                  body: Column(
                                                                    children: [
                                                                      Container(
                                                                        padding:
                                                                            EdgeInsets.all(
                                                                              16,
                                                                            ),
                                                                        color: Colors
                                                                            .blue
                                                                            .shade50,
                                                                        child: Column(
                                                                          children: [
                                                                            Text(
                                                                              'Expected Code: KU${nextBox}KU${order.oid}',
                                                                              style: TextStyle(
                                                                                fontSize: 16,
                                                                                fontWeight: FontWeight.bold,
                                                                                color: Colors.blue.shade800,
                                                                              ),
                                                                            ),
                                                                            Text(
                                                                              'Scanning box $nextBox of ${order.brojKutija}',
                                                                              style: TextStyle(
                                                                                color: Colors.blue.shade600,
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                      Expanded(
                                                                        child: MobileScanner(
                                                                          onDetect:
                                                                              (
                                                                                capture,
                                                                              ) {
                                                                                final List<
                                                                                  Barcode
                                                                                >
                                                                                barcodes = capture.barcodes;
                                                                                if (barcodes.isNotEmpty) {
                                                                                  final String code =
                                                                                      barcodes.first.rawValue ??
                                                                                      '';
                                                                                  print(
                                                                                    '🔍 Next box camera scan: $code',
                                                                                  );
                                                                                  Navigator.pop(
                                                                                    context,
                                                                                  );
                                                                                  smartIndividualScan(
                                                                                    code,
                                                                                  );
                                                                                }
                                                                              },
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          icon: Icon(
                                                            Icons.camera_alt,
                                                            size: 16,
                                                          ),
                                                          label: Text(
                                                            "Scan Next Box",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.blue,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 8,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                      ],

                                                      // Navigation button - only for accepted orders
                                                      if (isAccepted)
                                                        ElevatedButton.icon(
                                                          onPressed:
                                                              startMultiStopNavigation,
                                                          icon: Icon(
                                                            Icons.navigation,
                                                            size: 16,
                                                          ),
                                                          label: Text(
                                                            "Navigate",
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor:
                                                                Colors.green,
                                                            foregroundColor:
                                                                Colors.white,
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      12,
                                                                  vertical: 8,
                                                                ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bulkScanTimer?.cancel();
    super.dispose();
  }
}
