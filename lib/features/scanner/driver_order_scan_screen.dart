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

class DriverOrderScanScreen extends StatefulWidget {
  const DriverOrderScanScreen({super.key});

  @override
  State<DriverOrderScanScreen> createState() => _DriverOrderScanScreenState();
}

class _DriverOrderScanScreenState extends State<DriverOrderScanScreen> {
  final DeliveryRouteManager _routeManager = DeliveryRouteManager();
  final OfflineService _offlineService = OfflineService();

  Map<int, Set<int>> _scannedBoxesByOrder = {}; // Order ID -> Set of box IDs
  String statusMessage = '';
  bool loading = false;
  final Set<int> _expandedOrders = {};
  @override
  void initState() {
    super.initState();
    // Load any existing delivery stops
    setState(() {});
  }

  // Replace your current fetchOrder method with this one
  Future<void> fetchOrder(String code) async {
    setState(() {
      loading = true;
      statusMessage = '';
    });

    try {
      // Parse barcode to extract OID
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

      // Check connectivity
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

    // Find if we have this order
    final orderStop = _routeManager.allStops
        .where((stop) => stop.order.oid == orderId)
        .toList();
    if (orderStop.isEmpty) {
      setState(() => statusMessage = '❌ Prvo skenirajte narudžbu #$orderId.');
      return;
    }

    final boxNumber = _extractBoxNumber(code);
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

  int _extractBoxNumber(String code) {
    final parts = code.toLowerCase().split('ku');
    if (parts.length >= 2) {
      final boxPart = parts[1].split(
        RegExp(r'[^0-9]'),
      )[0]; // Extract just the numeric part
      return int.tryParse(boxPart) ?? 0;
    }
    return 0;
  }

  int _extractOrderId(String code) {
    // The order ID is typically at the end of the barcode after the last non-numeric character
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
                              : statusMessage.startsWith('❗')
                              ? Colors.orange
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                  // Navigation button if we have orders
                  if (allStops.isNotEmpty) ...[
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
                            "Ruta dostave: ${allStops.length} narudžbi",
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
                  // Replace your ListView.builder section with this
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
                              final isComplete =
                                  scannedCount >= order.brojKutija;

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
                                    color: isComplete
                                        ? Colors.green
                                        : Colors.blue.shade100,
                                    width: isComplete ? 2 : 1,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      // Toggle expanded state
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
                                              isComplete
                                                  ? Icons.check_circle
                                                  : Icons.local_shipping,
                                              color: isComplete
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

                                        // Expanded content - only visible when expanded
                                        if (isExpanded) ...[
                                          Divider(),

                                          // Customer information
                                          Text("📍 ${order.kupac.adresa}"),
                                          if (order.kupac.telefon.isNotEmpty)
                                            Text("📞 ${order.kupac.telefon}"),
                                          if (order.kupac.email.isNotEmpty)
                                            Text("📧 ${order.kupac.email}"),

                                          // Order notes
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

                                          // Order items section
                                          if (order.stavke.isNotEmpty) ...[
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 16,
                                                bottom: 8,
                                              ),
                                              child: Text(
                                                "STAVKE NARUDŽBE",
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                            ...order.stavke.map(
                                              (stavka) => Container(
                                                margin: EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                padding: EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      stavka.naziv,
                                                      style: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Text(
                                                          "Količina: ${stavka.kol}",
                                                        ),
                                                        Text(
                                                          "Cijena: ${stavka.cijena.toStringAsFixed(2)} KM",
                                                        ),
                                                      ],
                                                    ),
                                                    if (stavka.rabat > 0)
                                                      Text(
                                                        "Rabat: ${stavka.rabat}%",
                                                      ),
                                                    if (stavka.ean.isNotEmpty)
                                                      Text(
                                                        "EAN: ${stavka.ean}",
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 8),
                                        ],

                                        // Payment info - always visible but formatted differently based on expansion
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

                                        // Box count and scan button
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "📦 Kutije: $scannedCount/${order.brojKutija}",
                                              style: GoogleFonts.inter(
                                                color: isComplete
                                                    ? Colors.green
                                                    : Colors.blue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                if (!isComplete)
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      // Focus scanner to scan box for this order
                                                      scanBox(
                                                        "KU${scannedCount + 1}KU${order.oid}",
                                                      ); // Test scan next box
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
                                                IconButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            MultiStopNavigationScreen(),
                                                      ),
                                                    );
                                                  },
                                                  style: IconButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        Colors.white,
                                                  ),
                                                  icon: Icon(Icons.navigation),
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
