import 'package:digitalisapp/features/maps/delivery_route_manager.dart';
import 'package:digitalisapp/features/maps/multi_stop_navigation_screen.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DriverOrderScanScreen extends StatefulWidget {
  const DriverOrderScanScreen({super.key});

  @override
  State<DriverOrderScanScreen> createState() => _DriverOrderScanScreenState();
}

class _DriverOrderScanScreenState extends State<DriverOrderScanScreen> {
  final DeliveryRouteManager _routeManager = DeliveryRouteManager();
  Map<int, Set<int>> _scannedBoxesByOrder = {}; // Order ID -> Set of box IDs
  String statusMessage = '';
  bool loading = false;

  @override
  void initState() {
    super.initState();
    // Load any existing delivery stops
    setState(() {});
  }

  Future<void> fetchOrder(String code) async {
    setState(() {
      loading = true;
      statusMessage = '';
    });

    final response = await DriverApiService.fetchOrder(code);
    setState(() => loading = false);

    if (response['success'] == 1) {
      final fetchedOrder = DriverOrder.fromJson(response['data']);

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
    } else {
      setState(() {
        statusMessage = response['message'] ?? 'Greška.';
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
      body: Padding(
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
                    onPressed: () => fetchOrder("KU1KU2355445"),
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
                      label: Text("OPTIMIZIRANA NAVIGACIJA"),
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
                        final isComplete = scannedCount >= order.brojKutija;

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
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      child: Text(
                                        "Narudžba #${order.oid}",
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => removeOrder(order.oid),
                                      tooltip: 'Ukloni narudžbu',
                                    ),
                                  ],
                                ),
                                Divider(),
                                Text(
                                  "👤 ${order.kupac.naziv}",
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text("📍 ${order.kupac.adresa}"),
                                Text("📞 ${order.kupac.telefon}"),
                                if (order.napomena.isNotEmpty)
                                  Text(
                                    "📝 Napomena: ${order.napomena}",
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                if (order.napomenaVozac.isNotEmpty)
                                  Text(
                                    "🚨 Vozaču: ${order.napomenaVozac}",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  order.iznos > 0
                                      ? "💰 Naplatiti: ${order.iznos.toStringAsFixed(2)} KM"
                                      : order.trebaVratitiNovac
                                      ? "↩️ Povrat: ${order.iznos.abs().toStringAsFixed(2)} KM"
                                      : "✅ Bez naplate",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: order.trebaVratitiNovac
                                        ? Colors.red
                                        : Colors.green.shade800,
                                  ),
                                ),
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
                                    if (!isComplete)
                                      ElevatedButton(
                                        onPressed: () {
                                          // Focus scanner to scan box for this order
                                          scanBox(
                                            "KU${scannedCount + 1}KU${order.oid}",
                                          ); // Test scan next box
                                        },
                                        child: Text("Skeniraj kutiju"),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
