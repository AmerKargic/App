import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriversMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> drivers;

  const DriversMapScreen({Key? key, required this.drivers}) : super(key: key);

  @override
  State<DriversMapScreen> createState() => _DriversMapScreenState();
}

class _DriversMapScreenState extends State<DriversMapScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    print('Drivers data: ${widget.drivers}');

    _addDriverMarkersAndRoutes();
  }

  void _addDriverMarkersAndRoutes() {
    for (final driver in widget.drivers) {
      // Debugging: Log driver data
      print('Adding driver: ${driver['driver_name']}');
      print('Driver customers: ${driver['customers']}');
      print('Driver route: ${driver['route']}');

      // Parse driver's latitude and longitude
      final double driverLatitude =
          double.tryParse(driver['latitude']?.toString() ?? '0.0') ?? 0.0;
      final double driverLongitude =
          double.tryParse(driver['longitude']?.toString() ?? '0.0') ?? 0.0;

      // Add a marker for the driver
      final driverMarker = Marker(
        markerId: MarkerId('driver_${driver['driver_id']}'),
        position: LatLng(driverLatitude, driverLongitude),
        infoWindow: InfoWindow(
          title: 'Driver: ${driver['driver_name'] ?? 'Unknown'}',
          snippet: 'Driver ID: ${driver['driver_id'] ?? 'N/A'}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _markers.add(driverMarker);

      // Add customer markers if available
      if (driver['customers'] != null && driver['customers'] is List) {
        for (final customer in driver['customers']) {
          // Debugging: Log customer data
          print('Adding customer: ${customer['name'] ?? 'Unknown'}');

          final double customerLatitude =
              double.tryParse(customer['latitude']?.toString() ?? '0.0') ?? 0.0;
          final double customerLongitude =
              double.tryParse(customer['longitude']?.toString() ?? '0.0') ??
              0.0;

          final customerMarker = Marker(
            markerId: MarkerId('customer_${customer['name'] ?? 'unknown'}'),
            position: LatLng(customerLatitude, customerLongitude),
            infoWindow: InfoWindow(
              title: 'Customer: ${customer['name'] ?? 'Unknown'}',
              snippet: 'Address: ${customer['address'] ?? 'N/A'}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          );
          _markers.add(customerMarker);
        }
      } else {
        print('No customers found for driver: ${driver['driver_name']}');
      }

      // Add a polyline for the driver's route if available
      if (driver['route'] != null && driver['route'] is List) {
        // Debugging: Log route data
        print('Adding route for driver: ${driver['driver_name']}');

        final polyline = Polyline(
          polylineId: PolylineId('route_${driver['driver_id']}'),
          points: driver['route']
              .map<LatLng>(
                (point) => LatLng(
                  double.tryParse(point['latitude']?.toString() ?? '0.0') ??
                      0.0,
                  double.tryParse(point['longitude']?.toString() ?? '0.0') ??
                      0.0,
                ),
              )
              .toList(),
          color: Colors.blue,
          width: 4,
        );
        _polylines.add(polyline);
      } else {
        print('No route found for driver: ${driver['driver_name']}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers Map')),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(44.7866, 20.4489), // Example: Centered on Belgrade
          zoom: 10,
        ),
        markers: _markers,
        polylines: _polylines,
        onMapCreated: (controller) => _mapController = controller,
      ),
    );
  }
}
