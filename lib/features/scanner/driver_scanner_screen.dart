import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class VozacScannerScreen extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    _loadCachedData();
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('offline_delivery');
    if (cached != null) {
      shipmentData.value = jsonDecode(cached);
    }
  }

  Future<void> _saveOffline(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_delivery', jsonEncode(data));
  }

  void _onBarcodeScanned(String barcode) async {
    isLoading.value = true;

    try {
      // Simulate API response (replace with real API call)
      await Future.delayed(Duration(seconds: 1));

      shipmentData.value = {
        'barcode': barcode,
        'customer': 'John Doe',
        'address': '123 Test St, Sarajevo',
        'note': 'Leave at the door',
        'lat': 43.8563,
        'lng': 18.4131,
        'products': ['Laptop', 'Mouse'],
      };

      destination = LatLng(shipmentData['lat'], shipmentData['lng']);
      _updateMap();
    } catch (e) {
      Get.snackbar('Greška', 'Neuspješno dohvaćanje podataka');
    } finally {
      isLoading.value = false;
    }
  }

  void _updateMap() async {
    Position pos = await Geolocator.getCurrentPosition();
    currentLocation = LatLng(pos.latitude, pos.longitude);

    markers.clear();
    markers.add(Marker(markerId: MarkerId("you"), position: currentLocation!));
    if (destination != null) {
      markers.add(Marker(markerId: MarkerId("dest"), position: destination!));
    }

    setState(() {});
  }

  void _submitDelivery() async {
    final pos = await Geolocator.getCurrentPosition();
    shipmentData['delivered_at'] = DateTime.now().toIso8601String();
    shipmentData['gps_lat'] = pos.latitude;
    shipmentData['gps_lng'] = pos.longitude;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      await _saveOffline(shipmentData);
      Get.snackbar('Offline', 'Podaci su privremeno spremljeni.');
    } else {
      // TODO: send shipmentData to server
      Get.snackbar('Uspješno', 'Dostava zabilježena');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Vozac Dostava")),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: (barcodeCapture) {
                final code = barcodeCapture.barcodes.first.rawValue;
                if (code != null) _onBarcodeScanned(code);
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Obx(() {
              if (isLoading.value)
                return Center(child: CircularProgressIndicator());
              if (shipmentData.isEmpty)
                return Center(child: Text("Skenirajte label"));

              return ListView(
                padding: EdgeInsets.all(12),
                children: [
                  Text("Kupac: ${shipmentData['customer']}"),
                  Text("Adresa: ${shipmentData['address']}"),
                  Text("Napomena: ${shipmentData['note']}"),
                  ...shipmentData['products']
                      .map<Widget>((p) => Text("- $p"))
                      .toList(),
                  Container(
                    height: 200,
                    margin: EdgeInsets.only(top: 10),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: destination ?? LatLng(0, 0),
                        zoom: 13,
                      ),
                      onMapCreated: (c) => mapController = c,
                      markers: markers,
                    ),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text("Dostavljeno"),
                    onPressed: _submitDelivery,
                  ),
                  OutlinedButton.icon(
                    icon: Icon(Icons.error),
                    label: Text("Prijavi problem"),
                    onPressed: () {},
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
