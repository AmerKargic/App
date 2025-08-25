import 'dart:convert';
import 'dart:math';
import 'package:digitalisapp/features/dashboard/screens/driver_order_details_screen.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

class VozacScannerScreen extends StatefulWidget {
  final Function(String)? onBarcodeDetected; // New callback parameter

  const VozacScannerScreen({Key? key, this.onBarcodeDetected})
    : super(key: key);

  @override
  _VozacScannerScreenState createState() => _VozacScannerScreenState();
}

class _VozacScannerScreenState extends State<VozacScannerScreen> {
  final RxBool isLoading = false.obs;
  final RxMap<String, dynamic> shipmentData = <String, dynamic>{}.obs;
  GoogleMapController? mapController;
  LatLng? currentLocation;
  LatLng? destination;
  final Set<Marker> markers = {};
  final RxList<Map<String, dynamic>> blagOrders = <Map<String, dynamic>>[].obs;
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _hasDetectedBarcode = false;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _requestLocationPermission();
  }

  @override
  void dispose() {
    controller.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('offline_delivery');
    if (cached != null) {
      shipmentData.value = jsonDecode(cached);
      if (shipmentData.containsKey('lat') && shipmentData.containsKey('lng')) {
        destination = LatLng(
          double.parse(shipmentData['lat'].toString()),
          double.parse(shipmentData['lng'].toString()),
        );
        _updateMap();
      }
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_delivery', jsonEncode(data));
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasDetectedBarcode) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _hasDetectedBarcode = true;
        final String code = barcode.rawValue!;

        // Use the callback if provided
        if (widget.onBarcodeDetected != null) {
          widget.onBarcodeDetected!(code);
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          // Otherwise process internally
          _onBarcodeScanned(code);
        }
        break;
      }
    }
  }

  void _onBarcodeScanned(String barcode) async {
    isLoading.value = true;
    _hasDetectedBarcode = false; // Reset for future scans

    // Ako je blag dokument, koristi poseban flow
    if (barcode.toLowerCase().startsWith('blag')) {
      try {
        final resp = await DriverApiService.getDocumentsByDoc(barcode);
        if (resp['success'] == 1 && resp['documents'] != null) {
          final docs = List<Map<String, dynamic>>.from(
            resp['documents'] as List,
          );
          blagOrders.assignAll(docs);
          // Sortiraj po udaljenosti (ako imaš lokaciju)
          Position? pos;
          try {
            pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.best,
              timeLimit: const Duration(seconds: 7),
            );
          } catch (_) {
            pos = null;
          }

          final enriched = docs.map((d) {
            double? lat;
            double? lng;
            lat ??= (d['latitude'] as num?)?.toDouble();
            lng ??= (d['longitude'] as num?)?.toDouble();
            lat ??= (d['Kupac']?['latitude'] as num?)?.toDouble();
            lng ??= (d['Kupac']?['longitude'] as num?)?.toDouble();
            double distance = double.infinity;
            if (pos != null && lat != null && lng != null) {
              distance = Geolocator.distanceBetween(
                pos.latitude,
                pos.longitude,
                lat,
                lng,
              );
            }
            return {...d, '___distance': distance};
          }).toList();

          enriched.sort(
            (a, b) => (a['___distance'] as double).compareTo(
              b['___distance'] as double,
            ),
          );

          await _showBlagOrdersList(enriched);
          isLoading.value = false;
          return;
        } else {
          Get.snackbar(
            'Greška',
            resp['message'] ?? 'Nema narudžbi za ovaj blag dokument',
          );
          isLoading.value = false;
          return;
        }
      } catch (e) {
        Get.snackbar('Greška', 'Neuspješno dohvaćanje blag narudžbi: $e');
        isLoading.value = false;
        return;
      }
    }

    // Standardni flow za kutije (ostaje kao do sad)
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2/webshop/appinternal/api/driver_order.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': barcode}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == 1 && data['order'] != null) {
          shipmentData.value = {
            'barcode': barcode,
            'customer': data['order']['kupac']['naziv'] ?? 'Unknown',
            'address': data['order']['kupac']['adresa'] ?? 'No address',
            'note': data['order']['napomena'] ?? '',
            'lat': data['order']['kupac']['latitude'] ?? 0.0,
            'lng': data['order']['kupac']['longitude'] ?? 0.0,
            'products': (data['order']['stavke'] as List)
                .map((item) => item['naziv'])
                .toList(),
            'oid': data['order']['oid'],
            'box_number': data['order']['broj_kutija'],
          };

          destination = LatLng(
            double.parse(shipmentData['lat'].toString()),
            double.parse(shipmentData['lng'].toString()),
          );
          _updateMap();
        } else {
          Get.snackbar('Greška', data['message'] ?? 'Nepoznata greška');
        }
      } else {
        Get.snackbar('Greška', 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      Get.snackbar('Greška', 'Neuspješno dohvaćanje podataka: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Dodaj helper na dno klase:
  Future<void> _showBlagOrdersList(List<Map<String, dynamic>> docs) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.8,
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (c, i) {
                final d = docs[i];
                final kup = d['Kupac'] ?? {};
                final title =
                    kup['ImeZaNarudžbe'] ??
                    d['Dokument_ID']?.toString() ??
                    'Narudžba ${i + 1}';
                final addr = kup['Adresa1'] ?? '';
                final dist =
                    (d['___distance'] is double &&
                        (d['___distance'] as double).isFinite)
                    ? '${((d['___distance'] as double) / 1000).toStringAsFixed(2)} km'
                    : '—';
                return ListTile(
                  title: Text(title),
                  subtitle: Text('$addr • $dist'),
                  onTap: () {
                    Navigator.pop(ctx);
                    // Otvori detalje narudžbe i omogući dalje skeniranje kutija
                    final orderJson = {
                      'oid': d['oid_id'] ?? d['z_oid'] ?? 0,
                      'broj': d['Dokument_ID'] ?? '',
                      'kupac': kup,
                      'stavke': d['stavke'] ?? [],
                    };
                    final order = DriverOrder.fromJson(orderJson);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverOrderDetailsScreen(order: order),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _updateMap() async {
    try {
      Position pos = await Geolocator.getCurrentPosition();
      currentLocation = LatLng(pos.latitude, pos.longitude);

      markers.clear();
      markers.add(
        Marker(
          markerId: MarkerId("you"),
          position: currentLocation!,
          infoWindow: InfoWindow(title: "Vaša lokacija"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      if (destination != null) {
        markers.add(
          Marker(
            markerId: MarkerId("dest"),
            position: destination!,
            infoWindow: InfoWindow(
              title: shipmentData['customer'] ?? "Destinacija",
              snippet: shipmentData['address'] ?? "",
            ),
          ),
        );

        // Animate camera to show both markers
        if (mapController != null) {
          final bounds = LatLngBounds(
            southwest: LatLng(
              min(currentLocation!.latitude, destination!.latitude),
              min(currentLocation!.longitude, destination!.longitude),
            ),
            northeast: LatLng(
              max(currentLocation!.latitude, destination!.latitude),
              max(currentLocation!.longitude, destination!.longitude),
            ),
          );

          mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(bounds, 100),
          );
        }
      }

      setState(() {});
    } catch (e) {
      print('Error updating map: $e');
    }
  }

  void _submitDelivery() async {
    try {
      final pos = await Geolocator.getCurrentPosition();

      final deliveryData = {
        'oid': shipmentData['oid'],
        'box_number': shipmentData['box_number'],
        'delivered_at': DateTime.now().toIso8601String(),
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      };

      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        await _saveOffline(deliveryData);
        Get.snackbar('Offline', 'Podaci su privremeno spremljeni.');
      } else {
        // Send to server
        final response = await http.post(
          Uri.parse(
            //'https://www.digitalis.ba/webshop/appinternal/api/driver_scan_box.php',
            'http://10.0.2.2/webshop/appinternal/api/driver_scan_box.php',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'code': shipmentData['barcode']}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == 1) {
            Get.snackbar('Uspješno', 'Dostava zabilježena');
            // Clear the form after successful submission
            shipmentData.clear();
            markers.clear();
            setState(() {});
          } else {
            Get.snackbar('Greška', data['message'] ?? 'Nepoznata greška');
          }
        } else {
          Get.snackbar('Greška', 'Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      Get.snackbar('Greška', 'Neuspješno slanje podataka: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Skener dostave"),
        actions: [
          IconButton(
            icon: Icon(
              controller.torchEnabled ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: controller,
                  onDetect: _onBarcodeDetected,
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 50,
                            ),
                            SizedBox(height: 20),
                            Text(
                              'Pozicionirajte barkod unutar okvira',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.bug_report, color: Colors.white),
              label: Text('DEBUG: blag17635'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              onPressed: () async {
                _onBarcodeScanned('blag17635');
              },
            ),
          ),

          Expanded(
            flex: 3,
            child: Obx(() {
              if (isLoading.value)
                return Center(child: CircularProgressIndicator());

              // Prikaz blag narudžbi ako ih ima
              if (blagOrders.isNotEmpty) {
                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: blagOrders.length,
                  itemBuilder: (context, i) {
                    final d = blagOrders[i];
                    final kup = d['Kupac'] ?? {};
                    final title =
                        kup['ImeZaNarudžbe']?.toString().isNotEmpty == true
                        ? kup['ImeZaNarudžbe']
                        : 'Narudžba #${d['blg_id']}';
                    final addr = kup['Adresa1'] ?? '';
                    final iznos = d['OrderSummary']?['iznos']?.toString() ?? '';
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(title),
                        subtitle: Text('$addr | Iznos: $iznos'),
                        onTap: () {
                          final orderJson = {
                            'oid': d['oid_id'] ?? d['z_oid'] ?? 0,
                            'broj': d['Dokument_ID'] ?? '',
                            'kupac': kup,
                            'stavke': d['stavke'] ?? [],
                          };
                          final order = DriverOrder.fromJson(orderJson);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DriverOrderDetailsScreen(order: order),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              }

              // Prikaz kutije kao do sada
              if (shipmentData.isEmpty)
                return Center(child: Text("Skenirajte barkod kutije"));

              return ListView(
                padding: EdgeInsets.all(12),
                children: [
                  Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Kupac: ${shipmentData['customer']}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "Adresa: ${shipmentData['address']}",
                            style: TextStyle(fontSize: 15),
                          ),
                          if (shipmentData['note'] != null &&
                              shipmentData['note'] != '')
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                "Napomena: ${shipmentData['note']}",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Proizvodi:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          if (shipmentData['products'] != null)
                            ...List<String>.from(shipmentData['products'])
                                .map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4.0,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            p,
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    height: 200,
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: destination ?? LatLng(0, 0),
                          zoom: 13,
                        ),
                        onMapCreated: (c) {
                          mapController = c;
                          _updateMap();
                        },
                        markers: markers,
                        myLocationEnabled: true,
                        mapToolbarEnabled: true,
                      ),
                    ),
                  ),

                  SizedBox(height: 8),

                  ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text("Dostavljeno"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _submitDelivery,
                  ),

                  SizedBox(height: 8),

                  OutlinedButton.icon(
                    icon: Icon(Icons.error),
                    label: Text("Prijavi problem"),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      // Show problem reporting dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text("Prijavite problem"),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Izaberite razlog:"),
                              SizedBox(height: 8),
                              ListTile(
                                leading: Icon(Icons.home, color: Colors.red),
                                title: Text("Kupac nije na adresi"),
                                onTap: () {
                                  Navigator.pop(context);
                                  Get.snackbar(
                                    'Prijavljeno',
                                    'Problem prijavljen',
                                  );
                                },
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.money_off,
                                  color: Colors.red,
                                ),
                                title: Text("Problem s plaćanjem"),
                                onTap: () {
                                  Navigator.pop(context);
                                  Get.snackbar(
                                    'Prijavljeno',
                                    'Problem prijavljen',
                                  );
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.cancel, color: Colors.red),
                                title: Text("Kupac odbija dostavu"),
                                onTap: () {
                                  Navigator.pop(context);
                                  Get.snackbar(
                                    'Prijavljeno',
                                    'Problem prijavljen',
                                  );
                                },
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Zatvori"),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
