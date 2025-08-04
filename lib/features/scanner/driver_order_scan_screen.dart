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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digitalisapp/features/dashboard/screens/driver_order_screen.dart';
import 'package:location/location.dart' as loc;

class DriverOrderScanScreen extends StatefulWidget {
  const DriverOrderScanScreen({super.key});

  @override
  State<DriverOrderScanScreen> createState() => _DriverOrderScanScreenState();
}

class _DriverOrderScanScreenState extends State<DriverOrderScanScreen> {
  final DeliveryRouteManager _routeManager = DeliveryRouteManager();
  final OfflineService _offlineService = OfflineService();
  final loc.Location _location = loc.Location();
  Map<int, Set<int>> _scannedBoxesByOrder = {};
  // Order ID -> Set of box IDs
  Map<int, Set<int>> get scannedBoxesByOrder => _scannedBoxesByOrder;
  Map<int, bool> _acceptedOrders = {}; // Track accepted orders
  Map<int, Set<int>> _discardedBoxes = {};
  Map<int, StreamSubscription<loc.LocationData>?> _locationSubscriptions =
      {}; // Add this line
  Map<int, List<Map<String, dynamic>>> _locationLogs = {}; // Add this line

  String statusMessage = '';
  bool loading = false;
  final Set<int> _expandedOrders = {};
  @override
  void initState() {
    super.initState();
    // Load any existing delivery stops
    setState(() {});
  }

  void acceptOrder(int orderId) async {
    if (_acceptedOrders[orderId] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Narudžba #$orderId je već prihvaćena.")),
      );
      return;
    }
    setState(() {
      loading = true;
      statusMessage = 'Prihvaćanje narudžbe #$orderId...';
    });

    try {
      final response = await DriverApiService.acceptOrder(orderId);

      if (response['success'] == 1) {
        await DriverApiService.syncActivityLog({
          'log_type_id': 7,
          'oid': orderId,
          'description': 'Vozač preuzeo pošiljku',
          'timestamp': DateTime.now().toIso8601String(),
        });
        setState(() {
          _acceptedOrders[orderId] = true;
          loading = false;
          statusMessage = "✅ Narudžba #$orderId prihvaćena.";
        });

        _startLocationTracking(orderId);
      } else {
        setState(() {
          loading = false;
          statusMessage = '❌ ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        statusMessage = '❌ Greška: ${e.toString()}';
      });
    }
  }

  // Replace the completeOrder method with this:
  void completeOrder(int orderId) async {
    if (_acceptedOrders[orderId] != true) {
      return;
    }

    setState(() {
      loading = true;
      statusMessage = 'Završavanje narudžbe #$orderId...';
    });

    try {
      // Call API to complete order
      final response = await DriverApiService.completeOrder(orderId);

      if (response['success'] == 1) {
        // Log the completion using OfflineService instead of DriverApiService
        await _offlineService.logActivity(
          typeId: OfflineService.DRIVER_DELIVERY, // This is 9 - DELIVERY_END
          description: 'Vozač dostavio pošiljku',
          relatedId: orderId,
          extraData: {
            'oid': orderId,
            'action': 'delivery_completed',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        setState(() {
          _acceptedOrders[orderId] = false;
          loading = false;
          statusMessage = '✅ Narudžba #$orderId označena kao završena.';
        });

        // Stop location tracking placeholder
        _stopLocationTracking(orderId);
      } else {
        setState(() {
          loading = false;
          statusMessage = '❌ ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        loading = false;
        statusMessage = '❌ Greška: ${e.toString()}';
      });
    }
  }

  void _startLocationTracking(int orderId) {
    // Start location tracking using the existing location service from multi_stop_navigation_screen
    _location.onLocationChanged.listen((loc.LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null)
        return;

      // Create location data in the format expected by save_location.php
      final locationData = {
        'order_id': orderId,
        'latitude': currentLocation.latitude!,
        'longitude': currentLocation.longitude!,
        'accuracy': currentLocation.accuracy ?? 0.0,
        'speed': currentLocation.speed ?? 0.0,
        'heading': currentLocation.heading ?? 0.0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Store locally first
      _locationLogs[orderId] ??= [];
      _locationLogs[orderId]!.add(locationData);

      // Try to send to server immediately if connected
      _sendLocationToServer([locationData]);
    });

    print('Started location tracking for order $orderId');
  }

  void _stopLocationTracking(int orderId) {
    // Cancel the location subscription for this specific order
    _locationSubscriptions[orderId]?.cancel();
    _locationSubscriptions.remove(orderId);

    // Send any remaining location logs to server
    if (_locationLogs[orderId]?.isNotEmpty == true) {
      final unsentLogs = _locationLogs[orderId]!
          .where((log) => log['synced'] != true)
          .toList();
      if (unsentLogs.isNotEmpty) {
        _sendLocationToServer(unsentLogs);
      }
    }

    print('Stopped location tracking for order $orderId');
  }

  // Add this helper method to send location data to your save_location.php API
  // Replace the _sendLocationToServer method with this corrected version:
  Future<void> _sendLocationToServer(
    List<Map<String, dynamic>> locations,
  ) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // Will sync later when connection is available
    }

    try {
      // Convert the locations list to JSON string for the API
      final response = await DriverApiService.post('save_location.php', {
        'locations': jsonEncode(locations), // Convert List to JSON string
      });

      if (response['success'] == 1) {
        // Mark locations as synced
        for (final location in locations) {
          final orderId = location['order_id'];
          final index = _locationLogs[orderId]?.indexOf(location);
          if (index != null && index != -1) {
            _locationLogs[orderId]![index]['synced'] = true;
          }
        }
        print('Successfully sent ${locations.length} location updates');
      } else {
        print('Failed to send location updates: ${response['message']}');
      }
    } catch (e) {
      print('Error sending location updates: $e');
    }
  }

  // // Replace your current fetchOrder method with this one
  // Future<void> fetchOrder(String code) async {
  //   setState(() {
  //     loading = true;
  //     statusMessage = '';
  //   });

  //   try {
  //     // Parse barcode to extract OID
  //     RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
  //     final match = regex.firstMatch(code);
  //     if (match == null) {
  //       setState(() {
  //         loading = false;
  //         statusMessage = "❌ Neispravan format barkoda.";
  //       });
  //       return;
  //     }

  //     final boxNumber = int.parse(match.group(1)!);
  //     final oid = int.parse(match.group(2)!);

  //     // Check connectivity
  //     final connectivityResult = await Connectivity().checkConnectivity();

  //     // First check if we have this order in local storage
  //     final localOrder = await _offlineService.getOrder(oid);
  //     print("Local order for OID $oid: $localOrder");

  //     if (localOrder != null) {
  //       // Found locally, use it
  //       final fetchedOrder = DriverOrder.fromJson(localOrder);
  //       print("Fetched order from local storage: ${fetchedOrder.toJson()}");

  //       // Save the scanned box
  //       print(
  //         "Products being passed to saveScannedBox: ${fetchedOrder.stavke}",
  //       );
  //       await _offlineService.saveScannedBox(
  //         orderId: oid,
  //         boxNumber: boxNumber,
  //         boxBarcode: code,
  //         products: fetchedOrder.stavke,
  //       );

  //       // Log activity
  //       await _offlineService.logActivity(
  //         typeId: OfflineService.DRIVER_SCAN,
  //         description: 'Skeniran paket',
  //         relatedId: oid,
  //         extraData: {'box_number': boxNumber, 'box_code': code},
  //       );

  //       setState(() {
  //         loading = false;
  //         statusMessage = connectivityResult == ConnectivityResult.none
  //             ? "✅ Pronađena narudžba (offline)"
  //             : "✅ Pronađena narudžba";
  //       });

  //       // Process the order
  //       processOrder(fetchedOrder, code);
  //       return;
  //     }

  //     // If we're offline and don't have the order locally, show error
  //     if (connectivityResult == ConnectivityResult.none) {
  //       setState(() {
  //         loading = false;
  //         statusMessage =
  //             "❌ Narudžba nije pronađena u offline bazi. Potrebna internet konekcija.";
  //       });
  //       return;
  //     }

  //     // If we're online but don't have it locally, get from server
  //     final response = await DriverApiService.fetchOrder(code);
  //     print("API response: $response");

  //     setState(() => loading = false);

  //     if (response['success'] == 1) {
  //       // Check if order exists in the response
  //       if (response['order'] != null) {
  //         final fetchedOrder = DriverOrder.fromJson(response['order']);
  //         print("Fetched order from server: ${fetchedOrder.toJson()}");

  //         // Save order for offline use
  //         await _offlineService.saveOrder(fetchedOrder.oid, response['order']);

  //         // Save the scanned box
  //         print(
  //           "Products being passed to saveScannedBox: ${fetchedOrder.stavke}",
  //         );
  //         await _offlineService.saveScannedBox(
  //           orderId: fetchedOrder.oid,
  //           boxNumber: boxNumber,
  //           boxBarcode: code,
  //           products: fetchedOrder.stavke,
  //         );

  //         // Log activity
  //         await _offlineService.logActivity(
  //           typeId: OfflineService.DRIVER_SCAN,
  //           description: 'Skeniran paket',
  //           relatedId: fetchedOrder.oid,
  //           extraData: {'box_number': boxNumber, 'box_code': code},
  //         );

  //         processOrder(fetchedOrder, code);
  //       } else {
  //         setState(() {
  //           statusMessage = "❌ Neispravna struktura odgovora.";
  //         });
  //       }
  //     } else {
  //       setState(() {
  //         statusMessage = response['message'] ?? 'Greška.';
  //       });
  //     }
  //   } catch (e, stackTrace) {
  //     debugPrint("Error fetching order: $e");
  //     debugPrint("Stack trace: $stackTrace");
  //     setState(() {
  //       loading = false;
  //       statusMessage = "❌ Greška: ${e.toString()}";
  //     });
  //   }
  // } stara funkcija nova funkcija
  Future<void> fetchOrder(String code) async {
    setState(() {
      loading = true;
      statusMessage = '';
    });

    try {
      // Parse barcode to extract OID and box number
      RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
      final match = regex.firstMatch(code);
      if (match == null) {
        setState(() {
          loading = false;
          statusMessage = "❌ Neispravan format barkoda.";
        });
        return;
      }

      final boxNumber = int.parse(match.group(1)!);
      final oid = int.parse(match.group(2)!);

      // Check for conflicts BEFORE processing the order
      final conflictResponse = await DriverApiService.checkConflict(
        oid,
        boxNumber,
      );

      if (conflictResponse['success'] == 1 &&
          conflictResponse['conflict'] == true) {
        // Show conflict dialog
        _showConflictDialog(
          oid,
          boxNumber,
          conflictResponse['conflict_driver'] ?? 'Nepoznat vozač',
        );
        setState(() => loading = false);
        return;
      }

      // Continue with existing fetchOrder logic...
      final connectivityResult = await Connectivity().checkConnectivity();

      // First check if we have this order in local storage
      final localOrder = await _offlineService.getOrder(oid);
      print("Local order for OID $oid: $localOrder");

      if (localOrder != null) {
        // Found locally, use it
        final fetchedOrder = DriverOrder.fromJson(localOrder);
        print("Fetched order from local storage: ${fetchedOrder.toJson()}");

        // Save the scanned box
        print(
          "Products being passed to saveScannedBox: ${fetchedOrder.stavke}",
        );
        await _offlineService.saveScannedBox(
          orderId: oid,
          boxNumber: boxNumber,
          boxBarcode: code,
          products: fetchedOrder.stavke,
        );

        // Log activity
        await _offlineService.logActivity(
          typeId: OfflineService.DRIVER_SCAN,
          description: 'Skeniran paket',
          relatedId: oid,
          extraData: {'box_number': boxNumber, 'box_code': code},
        );

        setState(() {
          loading = false;
          statusMessage = connectivityResult == ConnectivityResult.none
              ? "✅ Pronađena narudžba (offline)"
              : "✅ Pronađena narudžba";
        });

        // Process the order
        processOrder(fetchedOrder, code);
        return;
      }

      // If we're offline and don't have the order locally, show error
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          loading = false;
          statusMessage =
              "❌ Narudžba nije pronađena u offline bazi. Potrebna internet konekcija.";
        });
        return;
      }

      // If we're online but don't have it locally, get from server
      final response = await DriverApiService.fetchOrder(code);
      print("API response: $response");

      setState(() => loading = false);

      if (response['success'] == 1) {
        // Check if order exists in the response
        if (response['order'] != null) {
          final fetchedOrder = DriverOrder.fromJson(response['order']);
          print("Fetched order from server: ${fetchedOrder.toJson()}");

          // Save order for offline use
          await _offlineService.saveOrder(fetchedOrder.oid, response['order']);

          // Save the scanned box
          print(
            "Products being passed to saveScannedBox: ${fetchedOrder.stavke}",
          );
          await _offlineService.saveScannedBox(
            orderId: fetchedOrder.oid,
            boxNumber: boxNumber,
            boxBarcode: code,
            products: fetchedOrder.stavke,
          );

          // Log activity
          await _offlineService.logActivity(
            typeId: OfflineService.DRIVER_SCAN,
            description: 'Skeniran paket',
            relatedId: fetchedOrder.oid,
            extraData: {'box_number': boxNumber, 'box_code': code},
          );

          processOrder(fetchedOrder, code);
        } else {
          setState(() {
            statusMessage = "❌ Neispravna struktura odgovora.";
          });
        }
      } else {
        setState(() {
          statusMessage = response['message'] ?? 'Greška.';
        });
      }
    } catch (e, stackTrace) {
      debugPrint("Error fetching order: $e");
      debugPrint("Stack trace: $stackTrace");
      setState(() {
        loading = false;
        statusMessage = "❌ Greška: ${e.toString()}";
      });
    }
  }

  void _showConflictDialog(int orderId, int boxNumber, String conflictDriver) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('KONFLIKT!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kutija #$boxNumber iz narudžbe #$orderId je već skenirana od strane:',
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
            Text('Ova kutija će biti automatski odbačena.'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _discardConflictedBox(
                orderId,
                boxNumber,
                'Konflikt sa vozačem: $conflictDriver',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Odbaci kutiju'),
          ),
        ],
      ),
    );
  }

  void _discardConflictedBox(int orderId, int boxNumber, String reason) async {
    try {
      // Add to discarded boxes
      if (!_discardedBoxes.containsKey(orderId)) {
        _discardedBoxes[orderId] = {};
      }
      _discardedBoxes[orderId]!.add(boxNumber);

      // Call API to discard box
      final response = await DriverApiService.discardBox(
        orderId,
        boxNumber,
        reason,
      );

      if (response['success'] == 1) {
        setState(() {
          statusMessage =
              '⚠️ Kutija #$boxNumber odbačena zbog konflikta. Možete nastaviti sa ostalim kutijama.';
        });
      } else {
        setState(() {
          statusMessage =
              '❌ Greška pri odbacivanju kutije: ${response['message']}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = '❌ Greška: ${e.toString()}';
      });
    }
  }

  // Add this helper method to process the order once retrieved
  void processOrder(DriverOrder fetchedOrder, String code) async {
    // Try to add to route manager
    final added = await _routeManager.addStop(fetchedOrder);

    if (added) {
      // Initialize box tracking for this order
      if (!_scannedBoxesByOrder.containsKey(fetchedOrder.oid)) {
        _scannedBoxesByOrder[fetchedOrder.oid] = {};
      }

      // Add the scanned box
      final boxNumber = _extractBoxNumber(code);
      _scannedBoxesByOrder[fetchedOrder.oid]!.add(boxNumber);

      setState(() {
        statusMessage =
            "✅ Dodana narudžba #${fetchedOrder.oid}. Ukupno: ${_routeManager.stopCount} narudžbi";
      });
    } else {
      setState(() {
        statusMessage = "⚠️ Narudžba #${fetchedOrder.oid} je već dodana.";
      });
    }
  }

  void scanBox(String code) async {
    // Find which order this box belongs to
    final orderId = _extractOrderId(code);
    if (orderId == 0) {
      setState(() => statusMessage = '❌ Pogrešan barkod.');
      return;
    }

    final boxNumber = _extractBoxNumber(code);

    // Check if this box was discarded
    if (_discardedBoxes[orderId]?.contains(boxNumber) == true) {
      setState(
        () =>
            statusMessage = '❌ Kutija #$boxNumber je odbačena zbog konflikta.',
      );
      return;
    }

    // Check for conflicts before scanning
    final conflictResponse = await DriverApiService.checkConflict(
      orderId,
      boxNumber,
    );

    if (conflictResponse['success'] == 1 &&
        conflictResponse['conflict'] == true) {
      _showConflictDialog(
        orderId,
        boxNumber,
        conflictResponse['conflict_driver'] ?? 'Nepoznat vozač',
      );
      return;
    }

    // Find if we have this order
    final orderStop = _routeManager.allStops
        .where((stop) => stop.order.oid == orderId)
        .toList();
    if (orderStop.isEmpty) {
      setState(() => statusMessage = '❌ Prvo skenirajte narudžbu #$orderId.');
      return;
    }

    if (_scannedBoxesByOrder[orderId]!.contains(boxNumber)) {
      setState(
        () => statusMessage =
            '❗ Kutija $boxNumber za narudžbu #$orderId je već skenirana.',
      );
      return;
    }

    final response = await DriverApiService.scanBox(code, orderId);

    if (response['success'] == 1) {
      setState(() {
        _scannedBoxesByOrder[orderId]!.add(boxNumber);
        final order = orderStop.first.order;
        statusMessage =
            "✅ Skenirana kutija $boxNumber/${order.brojKutija} za narudžbu #$orderId";
      });
    } else {
      setState(() {
        statusMessage = response['message'] ?? 'Greška skeniranja kutije.';
      });
    }
  }

  bool _canAcceptOrder(int orderId) {
    final order = _routeManager.allStops
        .where((stop) => stop.order.oid == orderId)
        .firstOrNull
        ?.order;

    if (order == null) return false;

    final scannedCount = _scannedBoxesByOrder[orderId]?.length ?? 0;
    final discardedCount = _discardedBoxes[orderId]?.length ?? 0;

    // Can accept if all non-discarded boxes are scanned
    return (scannedCount + discardedCount) >= order.brojKutija;
  }

  int _extractBoxNumber(String code) {
    final parts = code.toLowerCase().split('ku');
    if (parts.length >= 2) {
      final boxPart = parts[1].split(RegExp(r'[^0-9]'))[0];
      return int.tryParse(boxPart) ?? 0;
    }
    return 0;
  }

  int _extractOrderId(String code) {
    final match = RegExp(r'([0-9]+)$').firstMatch(code);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '0') ?? 0;
    }
    return 0;
  }

  void startMultiStopNavigation() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => MultiStopNavigationScreen()),
    );
  }

  void removeOrder(int orderId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ukloniti narudžbu?'),
        content: Text(
          'Da li ste sigurni da želite ukloniti narudžbu #$orderId iz rute?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () {
              _routeManager.removeStop(orderId);
              _scannedBoxesByOrder.remove(orderId);
              _acceptedOrders.remove(orderId);
              _discardedBoxes.remove(orderId);
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Ukloni'),
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
        title: Text('Očistiti sve?'),
        content: Text(
          'Da li ste sigurni da želite ukloniti sve narudžbe iz rute?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Odustani'),
          ),
          ElevatedButton(
            onPressed: () {
              _routeManager.clearStops();
              _scannedBoxesByOrder.clear();
              _acceptedOrders.clear();
              _discardedBoxes.clear();
              setState(() {});
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Očisti sve'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allStops = _routeManager.allStops;

    return Scaffold(
      appBar: AppBar(
        title: Text("Skeniranje paketa"),
        actions: [
          if (allStops.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_sweep),
              onPressed: clearAllOrders,
              tooltip: 'Očisti sve narudžbe',
            ),
        ],
      ),
      body: Column(
        children: [
          // Add offline status widget
          OfflineStatusWidget(
            onSyncPressed: () {
              _offlineService.syncNow().then((success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? "Sinhronizacija uspješna!"
                          : "Greška prilikom sinhronizacije",
                    ),
                  ),
                );
              });
            },
          ),

          // Rest of your existing body content wrapped in an Expanded widget
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Scanning section
                  HardwareBarcodeInput(
                    hintText: "Skeniraj barkod paketa...",
                    onBarcodeScanned: fetchOrder,
                  ),

                  // Test buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => fetchOrder("KU1KU2355444"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text("Test: Narudžba 1"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => fetchOrder("KU1KU2348560"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: Text("Test: Narudžba 2"),
                        ),
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

                  // Navigation button if we have accepted orders
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
                            "Ruta dostave: ${allStops.where((stop) => _acceptedOrders[stop.order.oid] == true).length} prihvaćenih narudžbi",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: startMultiStopNavigation,
                            icon: Icon(Icons.navigation),
                            label: Text("Pokreni NAVIGACIJU"),
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

                  // List of orders
                  const SizedBox(height: 16),
                  Expanded(
                    child: allStops.isEmpty
                        ? Center(
                            child: Text(
                              "Nema skeniranih narudžbi.\nSkenirajte barkod da dodate narudžbu.",
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
                              final totalProcessed =
                                  scannedCount + discardedCount;
                              final isComplete =
                                  totalProcessed >= order.brojKutija;
                              final isAccepted =
                                  _acceptedOrders[order.oid] == true;
                              final canAccept = _canAcceptOrder(order.oid);

                              // Track expanded state for each order
                              final isExpanded = _expandedOrders.contains(
                                order.oid,
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isAccepted
                                        ? Colors.orange
                                        : isComplete
                                        ? Colors.green
                                        : Colors.blue.shade100,
                                    width: (isAccepted || isComplete) ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (_expandedOrders.contains(order.oid)) {
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
                                        // Order header row - always visible
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
                                                    "Narudžba #${order.oid}",
                                                    style: GoogleFonts.inter(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    "👤 ${order.kupac.naziv}",
                                                    style: GoogleFonts.inter(),
                                                    maxLines: isExpanded
                                                        ? null
                                                        : 1,
                                                    overflow: isExpanded
                                                        ? null
                                                        : TextOverflow.ellipsis,
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
                                                  if (_expandedOrders.contains(
                                                    order.oid,
                                                  )) {
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
                                              tooltip: 'Ukloni narudžbu',
                                            ),
                                          ],
                                        ),

                                        // Show tracking status if active
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
                                                    "Narudžba prihvaćena - spremna za navigaciju",
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

                                        // Show discarded boxes if any
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
                                                    "Odbačeno kutija: $discardedCount (konflikti)",
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

                                        // Expanded content - only visible when expanded
                                        if (isExpanded) ...[
                                          Divider(),
                                          Text("📍 ${order.kupac.adresa}"),
                                          if (order.kupac.telefon.isNotEmpty)
                                            Text("📞 ${order.kupac.telefon}"),
                                          if (order.kupac.email.isNotEmpty)
                                            Text("📧 ${order.kupac.email}"),
                                          if (order.napomena.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                "📝 Napomena: ${order.napomena}",
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
                                                "🚨 Vozaču: ${order.napomenaVozac}",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
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
                                                  color: order.trebaVratitiNovac
                                                      ? Colors.red.shade50
                                                      : order.iznos > 0
                                                      ? Colors.green.shade50
                                                      : Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                )
                                              : null,
                                          child: Text(
                                            order.iznos > 0
                                                ? "💰 Naplatiti: ${order.iznos.toStringAsFixed(2)} KM"
                                                : order.trebaVratitiNovac
                                                ? "↩️ Povrat: ${order.iznos.abs().toStringAsFixed(2)} KM"
                                                : "✅ Bez naplate",
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

                                        // Box count and buttons
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
                                                  "📦 Ukupno: ${order.brojKutija} kutija",
                                                  style: GoogleFonts.inter(
                                                    color: Colors.grey.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  "✅ Skenirano: $scannedCount kutija",
                                                  style: GoogleFonts.inter(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (discardedCount > 0)
                                                  Text(
                                                    "❌ Odbačeno: $discardedCount kutija",
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
                                                // Accept/Complete button - positioned at the bottom of the order card
                                                ElevatedButton(
                                                  onPressed: isAccepted
                                                      ? () => completeOrder(
                                                          order.oid,
                                                        )
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
                                                        ? "Završi dostavu"
                                                        : canAccept
                                                        ? "Prihvati narudžbu"
                                                        : "Skeniraj sve kutije",
                                                  ),
                                                ),

                                                const SizedBox(height: 4),

                                                // Scan Box button (if not complete)
                                                Row(
                                                  children: [
                                                    if (!isComplete)
                                                      ElevatedButton(
                                                        onPressed: () {
                                                          scanBox(
                                                            "KU${scannedCount + 1}KU${order.oid}",
                                                          );
                                                        },
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.blue,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        child: Text(
                                                          "Skeniraj kutiju",
                                                        ),
                                                      ),
                                                    const SizedBox(width: 8),

                                                    // Navigation button - only for accepted orders
                                                    if (isAccepted)
                                                      IconButton(
                                                        onPressed:
                                                            startMultiStopNavigation,
                                                        style:
                                                            IconButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.green,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                        icon: Icon(
                                                          Icons.navigation,
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
}
