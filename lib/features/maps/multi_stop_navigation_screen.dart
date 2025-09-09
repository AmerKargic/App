import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:digitalisapp/features/maps/delivery_route_manager.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/models/offline_status_widget.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';

class MultiStopNavigationScreen extends StatefulWidget {
  const MultiStopNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MultiStopNavigationScreen> createState() =>
      _MultiStopNavigationScreenState();
}

class _MultiStopNavigationScreenState extends State<MultiStopNavigationScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _controller = Completer();
  final loc.Location _location = loc.Location();
  final DeliveryRouteManager _routeManager = DeliveryRouteManager();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, dynamic> _routeData = {}; // To store all route data
  final OfflineService _offlineService = OfflineService();
  final offlineService = OfflineService();
  LatLng? _currentPosition;
  bool _loading = true;
  String _statusMessage = "Učitavanje...";
  double _totalDistance = 0;
  String _totalEstimatedTime = "";
  bool _mapReady = false;
  int _selectedStopIndex = 0;

  // Navigation variables
  bool _navigationActive = false;
  List<Map<String, dynamic>> _navigationSteps = [];
  int _currentStepIndex = 0;
  Timer? _navigationTimer;
  bool _cameraAnimationInProgress = false;
  bool _freeMapControl = false;
  bool _showLocationButton = true;
  bool _arrivalNotified = false;
  bool _showingTurnAlert = false;

  @override
  void initState() {
    super.initState();

    // Add test stops if there are none
    final routeManager = DeliveryRouteManager();
    if (routeManager.stopCount == 0) {
      // Create test orders with different locations in Sarajevo
      final testLocations = [
        {"lat": 43.8563, "lng": 18.4131}, // Sarajevo center
        {"lat": 43.8490, "lng": 18.3550}, // Location west
        {"lat": 43.8650, "lng": 18.4350}, // Location northeast
      ];

      // Add test orders
      for (int i = 0; i < testLocations.length; i++) {
        final kupac = Kupac(
          naziv: "Test Customer ${i + 1}",
          adresa: "Test Address",
          opstina: "Sarajevo",
          drzava: "BiH",
          telefon: "123456789",
          email: "",
        );
      }
    }

    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background, reduce update frequency
      _navigationTimer?.cancel();
      _navigationTimer = Timer.periodic(Duration(minutes: 5), (timer) {
        if (mounted && _navigationActive) _updateNavigationProgress();
      });
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground, restore update frequency
      _navigationTimer?.cancel();
      _navigationTimer = Timer.periodic(Duration(minutes: 1), (timer) {
        if (mounted && _navigationActive) _updateNavigationProgress();
      });
    }
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    await _getLocationUpdates();
    await _checkEmulatorAndFallback();
    await _calculateMultiStopRoute();
  }

  Future<void> _requestPermissions() async {
    print("Requesting location permissions...");

    // Request location permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
    ].request();

    if (statuses[Permission.location]!.isDenied) {
      // Show dialog explaining why we need permissions
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Potrebne dozvole'),
            content: Text(
              'Za navigaciju je potreban pristup lokaciji. '
              'Molimo dozvolite pristup lokaciji u postavkama aplikacije.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Otvori postavke'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _enableDemoMode();
                },
                child: Text('Koristi demo mod'),
              ),
            ],
          ),
        );
      }
    } else if (statuses[Permission.location]!.isPermanentlyDenied) {
      // User permanently denied permission
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Dozvola odbijena'),
            content: Text(
              'Lokacija je trajno odbijena. Molimo omogućite lokaciju '
              'u postavkama aplikacije.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Otvori postavke'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _enableDemoMode();
                },
                child: Text('Koristi demo mod'),
              ),
            ],
          ),
        );
      }
    } else {
      // Permission granted, check if location services are enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();

        if (!serviceEnabled && mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('GPS isključen'),
              content: Text(
                'Potrebno je uključiti GPS za navigaciju. '
                'Molimo uključite GPS u postavkama telefona.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _enableDemoMode();
                  },
                  child: Text('Koristi demo mod'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _getLocationUpdates() async {
    // Check location permission first
    final permissionStatus = await _location.hasPermission();
    if (permissionStatus == loc.PermissionStatus.denied ||
        permissionStatus == loc.PermissionStatus.deniedForever) {
      setState(() {
        _statusMessage = "Pristup lokaciji nije dozvoljen.";
      });
      return;
    }

    // Check if location service is enabled
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = "Molimo uključite GPS servis.";
        });
        return;
      }
    }

    // Configure location service
    await _location.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 5000, // 5 seconds
    );

    // Get initial location
    try {
      final initialLocation = await _location.getLocation();
      if (initialLocation.latitude != null &&
          initialLocation.longitude != null) {
        setState(() {
          _currentPosition = LatLng(
            initialLocation.latitude!,
            initialLocation.longitude!,
          );
          _statusMessage = "Lokacija pronađena!";

          _markers.add(
            Marker(
              markerId: const MarkerId('current'),
              position: _currentPosition!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: const InfoWindow(title: "Vaša lokacija"),
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Greška pri dohvatu lokacije: $e";
      });
    }

    // Start location updates
    _location.onLocationChanged.listen((loc.LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null)
        return;

      final newPosition = LatLng(
        currentLocation.latitude!,
        currentLocation.longitude!,
      );

      // Only update if position actually changed significantly (3 meters)
      final distanceMoved = _currentPosition != null
          ? _calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  newPosition.latitude,
                  newPosition.longitude,
                ) *
                1000
          : 0; // Convert to meters

      if (_currentPosition == null || distanceMoved > 3) {
        setState(() {
          _currentPosition = newPosition;

          // Update current location marker
          _markers.removeWhere((m) => m.markerId.value == 'current');
          _markers.add(
            Marker(
              markerId: const MarkerId('current'),
              position: _currentPosition!,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
              infoWindow: const InfoWindow(title: "Vaša lokacija"),
              zIndex: 100, // Make sure it's on top
            ),
          );
        });

        // Update navigation when active
        if (_navigationActive &&
            !_cameraAnimationInProgress &&
            !_freeMapControl) {
          _animateToCurrentLocationWithHeading();
        }

        // Check for arrival at the current stop
      }
    });
  }

  Future<void> _checkEmulatorAndFallback() async {
    // Wait a few seconds to see if we get real location data
    await Future.delayed(const Duration(seconds: 3));

    // If still no location, we're probably on an emulator or GPS is disabled
    if (_currentPosition == null && mounted) {
      print("No location after timeout - using default location");
      setState(() {
        _currentPosition = const LatLng(43.8563, 18.4131); // Sarajevo

        _markers.add(
          Marker(
            markerId: const MarkerId('current'),
            position: _currentPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: "Vaša lokacija (emulator)"),
          ),
        );

        _statusMessage = "Koristi se lokacija emulatora";
      });
    }
  }

  void _enableDemoMode() {
    // Create demo coordinates with Sarajevo as center
    final demoCurrentPos = const LatLng(43.8563, 18.4131); // Sarajevo center

    setState(() {
      _currentPosition = demoCurrentPos;

      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: demoCurrentPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: "Vaša lokacija (demo)"),
        ),
      );

      // Add demo stops (if there aren't any real ones)
      if (_routeManager.stopCount == 0) {
        // Add demo markers around Sarajevo
        const double radius = 0.02;
        final random = math.Random();

        for (int i = 1; i <= 4; i++) {
          final angle = i * (360 / 4) * (math.pi / 180);
          final lat = demoCurrentPos.latitude + radius * math.cos(angle);
          final lng = demoCurrentPos.longitude + radius * math.sin(angle);

          _markers.add(
            Marker(
              markerId: MarkerId('demo_stop_$i'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                i == _selectedStopIndex
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: "Demo Kupac $i",
                snippet: "Demo adresa $i",
              ),
            ),
          );
        }

        // Add a demo route
        List<LatLng> demoPoints = [];
        demoPoints.add(demoCurrentPos);

        // Add points connecting the current location to each stop
        for (int i = 1; i <= 4; i++) {
          final angle = i * (360 / 4) * (math.pi / 180);
          final lat = demoCurrentPos.latitude + radius * math.cos(angle);
          final lng = demoCurrentPos.longitude + radius * math.sin(angle);

          // Add some intermediate points to make it look more like a real route
          const int steps = 5;
          for (int j = 1; j <= steps; j++) {
            final t = j / steps;
            final intermediateLat =
                demoCurrentPos.latitude + t * radius * math.cos(angle);
            final intermediateLng =
                demoCurrentPos.longitude + t * radius * math.sin(angle);
            demoPoints.add(LatLng(intermediateLat, intermediateLng));
          }
        }

        _polylines.add(
          Polyline(
            polylineId: const PolylineId('demo_route'),
            color: Colors.blue,
            points: demoPoints,
            width: 5,
          ),
        );

        // Set demo data
        _totalDistance = 5.2; // 5.2 km total route
        _totalEstimatedTime = "25 min"; // 25 minutes total time
      }

      _loading = false;
      _mapReady = true;
      _statusMessage = "Demo način rada aktiviran";
    });

    // Force map to show all points
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_controller.isCompleted) {
        _fitAllMarkers();
      }
    });
  }

  // Calculate the optimized route for all stops
  Future<void> _calculateMultiStopRoute() async {
    if (_currentPosition == null) {
      // Wait for location before calculating route
      await Future.delayed(Duration(seconds: 1));
      if (_currentPosition == null) {
        setState(() {
          _statusMessage = "Čekam lokaciju...";
        });
        return;
      }
    }

    setState(() {
      _statusMessage = "Izračunavam optimalnu rutu...";
      _loading = true;
    });

    try {
      // Get optimized route from RouteManager
      final optimizedStops = _routeManager.optimizedRoute;

      // If no stops, show error and return
      if (optimizedStops.isEmpty) {
        setState(() {
          _statusMessage = "Nema destinacija za rutu.";
          _loading = false;
        });
        return;
      }

      // Reset markers and add current location
      _markers.clear();
      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current'),
            position: _currentPosition!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: "Vaša lokacija"),
            zIndex: 100, // Ensure it's on top
          ),
        );
      }

      // Add markers for each stop
      for (int i = 0; i < optimizedStops.length; i++) {
        final stop = optimizedStops[i];
        final order = stop.order;

        _markers.add(
          Marker(
            markerId: MarkerId('stop_${order.oid}'),
            position: stop.coordinates,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == _selectedStopIndex
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: order.kupac.naziv,
              snippet: order.kupac.adresa,
            ),
            onTap: () {
              setState(() {
                _selectedStopIndex = i;
                _updateSelectedStopMarkers();
              });
            },
          ),
        );
      }

      // Use the Google Directions API to get the detailed route
      final String apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo";

      // Build waypoints from all stops except origin and destination
      final List<String> waypoints = [];

      if (optimizedStops.length > 1) {
        for (int i = 0; i < optimizedStops.length; i++) {
          final stop = optimizedStops[i];
          waypoints.add(
            "${stop.coordinates.latitude},${stop.coordinates.longitude}",
          );
        }
      }

      // Origin is always current location
      final origin =
          "${_currentPosition!.latitude},${_currentPosition!.longitude}";

      // Destination is the first stop
      final destination =
          "${optimizedStops[0].coordinates.latitude},${optimizedStops[0].coordinates.longitude}";

      // Format waypoints for URL (skip first since it's the destination)
      final formattedWaypoints = waypoints.skip(1).join('|');

      final Uri directionsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        '${formattedWaypoints.isNotEmpty ? 'waypoints=$formattedWaypoints&' : ''}'
        'mode=driving&'
        'key=$apiKey',
      );

      final response = await http.get(directionsUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _routeData.clear();
        _routeData.addAll(data);

        if (data["status"] == "OK") {
          final routes = data["routes"];

          if (routes.isNotEmpty) {
            // Build detailed polyline from all steps in all legs
            List<LatLng> detailedPolylineCoordinates = [];
            double totalDistance = 0;
            int totalDuration = 0;

            final legs = routes[0]["legs"];

            for (var leg in legs) {
              totalDistance +=
                  leg["distance"]["value"] / 1000.0; // Convert to km
              // Replace line 553:
              totalDuration += ((leg["duration"]["value"] / 60) as num)
                  .toInt(); // Convert to minutes // Convert to minutes

              // Get all steps to build detailed polyline
              final steps = leg["steps"];

              for (var step in steps) {
                // Get the polyline for this specific step
                final stepPolyline = step["polyline"]["points"];
                final List<PointLatLng> stepPoints = PolylinePoints()
                    .decodePolyline(stepPolyline);

                // Add all points from this step to our detailed route
                detailedPolylineCoordinates.addAll(
                  stepPoints.map(
                    (point) => LatLng(point.latitude, point.longitude),
                  ),
                );
              }
            }

            setState(() {
              _totalDistance = totalDistance;
              _totalEstimatedTime = "${totalDuration.round()} min";

              // Create polyline with the detailed route points
              _polylines.clear();
              _polylines.add(
                Polyline(
                  polylineId: const PolylineId('route'),
                  color: Colors.blue,
                  points: detailedPolylineCoordinates,
                  width: 5,
                ),
              );

              _statusMessage =
                  "Ruta izračunata: "
                  "${totalDistance.toStringAsFixed(1)} km, ${totalDuration.round()} min";
              _loading = false;
            });

            // Extract navigation steps for the first leg (to the first stop)
            _extractNavigationSteps();

            _fitAllMarkers();
            return;
          }
        } else {
          print("Directions API error: ${data["status"]}");
          setState(() {
            _statusMessage = "API greška: ${data["status"]}";
          });
        }
      }

      // If we reach here, something went wrong with the API call
      _createFallbackRoute();
    } catch (e) {
      print("Error calculating multi-stop route: $e");
      setState(() {
        _statusMessage = "Greška pri izračunu rute: $e";
      });

      // Fall back to simple route
      _createFallbackRoute();
    }
  }

  void _createFallbackRoute() {
    final optimizedStops = _routeManager.optimizedRoute;

    if (optimizedStops.isEmpty || _currentPosition == null) {
      setState(() {
        _loading = false;
        _statusMessage = "Nema podataka za rutu.";
      });
      return;
    }

    // Create a simple polyline connecting all points
    List<LatLng> points = [_currentPosition!];

    for (final stop in optimizedStops) {
      points.add(stop.coordinates);
    }

    setState(() {
      // Calculate straight-line distance
      double totalDistance = 0;
      for (int i = 0; i < points.length - 1; i++) {
        totalDistance += _calculateDistance(
          points[i].latitude,
          points[i].longitude,
          points[i + 1].latitude,
          points[i + 1].longitude,
        );
      }

      _totalDistance = totalDistance;

      // Estimate time (very rough - assumes 30km/h average speed in city)
      final minutes = (totalDistance / 30 * 60).round();
      _totalEstimatedTime = "${minutes} min";

      // Create a polyline
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: points,
          width: 5,
        ),
      );

      _statusMessage = "Jednostavna ruta izračunata (zračna linija)";
      _loading = false;
    });

    _fitAllMarkers();
  }

  // Calculate the distance between two points
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 *
        math.asin(math.sqrt(a)); // 2 * R * asin(sqrt(a)), R = 6371 km
  }

  // Zoom to show all markers on the map
  Future<void> _fitAllMarkers() async {
    if (!_controller.isCompleted || _markers.isEmpty) return;

    final controller = await _controller.future;

    // Create bounds from all markers
    double minLat = 90;
    double maxLat = -90;
    double minLng = 180;
    double maxLng = -180;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Add some padding
    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  // Focus on current location
  Future<void> _animateToCurrentLocation() async {
    if (_currentPosition == null || !_controller.isCompleted) return;

    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
  }

  // Focus on selected stop
  void _focusOnSelectedStop() async {
    if (!_controller.isCompleted) return;

    final optimizedStops = _routeManager.optimizedRoute;
    if (optimizedStops.isEmpty || _selectedStopIndex >= optimizedStops.length)
      return;

    final stop = optimizedStops[_selectedStopIndex];
    final controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newLatLngZoom(stop.coordinates, 15));
  }

  void _updateSelectedStopMarkers() {
    // Update marker colors to reflect the selected stop
    final optimizedStops = _routeManager.optimizedRoute;

    _markers.removeWhere((marker) => marker.markerId.value.startsWith('stop_'));

    for (int i = 0; i < optimizedStops.length; i++) {
      final stop = optimizedStops[i];
      final order = stop.order;

      _markers.add(
        Marker(
          markerId: MarkerId('stop_${order.oid}'),
          position: stop.coordinates,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            i == _selectedStopIndex
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: order.kupac.naziv,
            snippet: order.kupac.adresa,
          ),
          onTap: () {
            setState(() {
              _selectedStopIndex = i;
              _updateSelectedStopMarkers();
            });
          },
        ),
      );
    }
  }

  // Fix in _startNavigation method
  Future<void> _startNavigation() async {
    setState(() => _loading = true);

    if (_routeManager.optimizedRoute.isEmpty || _currentPosition == null) {
      setState(() {
        _statusMessage =
            "Nema odabranih destinacija ili lokacija nije dostupna.";
        _loading = false;
      });
      return;
    }

    // Get the current destination
    final selectedStop = _routeManager.optimizedRoute[_selectedStopIndex];

    // Log that we started navigation to this order
    _offlineService.logActivity(
      typeId: OfflineService.DRIVER_IN_TRANSIT,
      description: 'Započeta dostava',
      relatedId: selectedStop.order.oid,
      text: 'Navigation started',
      extraData: {
        'customer_name': selectedStop.order.kupac.naziv,
        'distance': _currentPosition != null
            ? _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                selectedStop.coordinates.latitude,
                selectedStop.coordinates.longitude,
              )
            : 0.0,
        'estimated_time': _totalEstimatedTime,
      },
    );

    try {
      // Sync all box data
      await _offlineService.syncBoxesAndProducts();

      setState(() {
        _loading = false;
        _statusMessage = "✅ Podaci sinhronizirani!";
      });
      _offlineService.activateRoute();

      // Calculate the route for in-app navigation
      await _calculateMultiStopRoute();

      // Focus on the selected stop
      _focusOnSelectedStop();

      // Enable navigation mode
      setState(() {
        _navigationActive = true;
        _arrivalNotified = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _statusMessage = "Greška prilikom pokretanja navigacije: $e";
      });
    }
  }

  void _stopNavigation() {
    setState(() {
      _navigationActive = false;
      _navigationTimer?.cancel();
    });
    _offlineService.deactivateRoute();
    _fitAllMarkers();
  }

  void _extractNavigationSteps() {
    if (_routeData.isEmpty ||
        !_routeData.containsKey("routes") ||
        _routeData["routes"].isEmpty) {
      _setDefaultNavigationSteps();
      return;
    }

    try {
      // Get the first leg (to the current selected stop)
      final route = _routeData["routes"][0];
      if (!route.containsKey("legs") || route["legs"].isEmpty) {
        _setDefaultNavigationSteps();
        return;
      }

      // Use the appropriate leg based on selected stop
      final leg = route["legs"][_selectedStopIndex];
      final steps = leg["steps"];

      if (steps == null || steps.isEmpty) {
        _setDefaultNavigationSteps();
        return;
      }

      // Parse steps into navigation instructions
      List<Map<String, dynamic>> navigationSteps = [];

      // Add starting instruction
      navigationSteps.add({
        'instruction': 'Krećete prema odredištu',
        'distance': leg["distance"]["value"] / 1000.0, // Convert to km
        'maneuver': 'start',
        'icon': Icons.arrow_upward,
      });

      // Process each step
      for (var step in steps) {
        // Get instruction text (remove HTML tags)
        String instruction = step["html_instructions"];
        instruction = instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
        instruction = instruction.replaceAll('  ', ' ').trim();

        // Determine icon based on maneuver or text content
        IconData icon = Icons.arrow_upward;
        String maneuver = step["maneuver"] ?? "";

        if (maneuver.contains("turn-right")) {
          icon = Icons.turn_right;
        } else if (maneuver.contains("turn-left")) {
          icon = Icons.turn_left;
        } else if (maneuver.contains("roundabout")) {
          icon = Icons.roundabout_left;
        } else if (instruction.toLowerCase().contains("desno")) {
          icon = Icons.turn_right;
        } else if (instruction.toLowerCase().contains("lijevo")) {
          icon = Icons.turn_left;
        }

        navigationSteps.add({
          'instruction': instruction,
          'distance': step["distance"]["value"] / 1000.0, // Convert to km
          'maneuver': maneuver,
          'icon': icon,
        });
      }

      // Add arrival step
      final optimizedStops = _routeManager.optimizedRoute;
      final selectedStop = optimizedStops[_selectedStopIndex];

      navigationSteps.add({
        'instruction':
            'Stigli ste na odredište ${selectedStop.order.kupac.naziv}',
        'distance': 0.0,
        'maneuver': 'arrive',
        'icon': Icons.location_on,
      });

      setState(() {
        _navigationSteps = navigationSteps;
        _currentStepIndex = 0;
      });
    } catch (e) {
      print("Error extracting navigation steps: $e");
      _setDefaultNavigationSteps();
    }
  }

  void _setDefaultNavigationSteps() {
    if (_routeManager.optimizedRoute.isEmpty) return;

    final selectedStop = _routeManager.optimizedRoute[_selectedStopIndex];
    final distanceToStop = _currentPosition != null
        ? _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            selectedStop.coordinates.latitude,
            selectedStop.coordinates.longitude,
          )
        : 5.0; // Default 5km if current position unknown

    setState(() {
      _navigationSteps = [
        {
          'instruction': 'Krenite prema odredištu',
          'distance': distanceToStop,
          'maneuver': 'start',
          'icon': Icons.arrow_upward,
        },
        {
          'instruction': 'Pratite rutu',
          'distance': distanceToStop * 0.5,
          'maneuver': 'straight',
          'icon': Icons.straight,
        },
        {
          'instruction': 'Približavate se odredištu',
          'distance': distanceToStop * 0.2,
          'maneuver': 'approaching',
          'icon': Icons.location_searching,
        },
        {
          'instruction':
              'Stigli ste na odredište ${selectedStop.order.kupac.naziv}',
          'distance': 0.0,
          'maneuver': 'arrive',
          'icon': Icons.location_on,
        },
      ];
      _currentStepIndex = 0;
    });
  }

  Future<void> _animateToCurrentLocationWithHeading() async {
    if (_currentPosition == null || !_controller.isCompleted) return;

    // Skip if user is manually controlling the map
    if (_freeMapControl) return;

    // Skip if animation already in progress
    if (_cameraAnimationInProgress) return;
    _cameraAnimationInProgress = true;

    final controller = await _controller.future;
    double bearing = _getHeadingToDestination();

    // Use different zoom levels based on speed (if available)
    double zoomLevel = 18.0;
    double lookAheadFactor = 0.0002; // How far ahead to look

    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              _currentPosition!.latitude +
                  (lookAheadFactor * math.sin(bearing * math.pi / 180)),
              _currentPosition!.longitude +
                  (lookAheadFactor * math.cos(bearing * math.pi / 180)),
            ),
            zoom: zoomLevel,
            tilt: 60.0,
            bearing: bearing,
          ),
        ),
      );
    } catch (e) {
      print("Camera animation error: $e");
    }

    // Shorter delay for more responsive updates
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _cameraAnimationInProgress = false;
    });
  }

  double _getHeadingToDestination() {
    if (_currentPosition == null || _routeManager.optimizedRoute.isEmpty)
      return 0;

    // Get the current target stop
    final selectedStop = _routeManager.optimizedRoute[_selectedStopIndex];
    LatLng targetPoint = selectedStop.coordinates;

    // If we have navigation active and polylines exist
    if (_navigationActive &&
        _polylines.isNotEmpty &&
        _polylines.first.points.length > 1) {
      // Get all points in the polyline
      final points = _polylines.first.points;

      // Find a point that's ahead of us on the route
      double minDistance = double.infinity;
      int currentIndex = -1;

      // First find where we are on the route
      for (int i = 0; i < points.length; i++) {
        double dist = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          points[i].latitude,
          points[i].longitude,
        );

        if (dist < minDistance) {
          minDistance = dist;
          currentIndex = i;
        }
      }

      // Then look ahead on the route to get our heading
      if (currentIndex != -1) {
        // Look ahead by a few points if possible
        int lookAheadIndex = math.min(currentIndex + 3, points.length - 1);
        if (currentIndex != lookAheadIndex) {
          targetPoint = points[lookAheadIndex];
        }
      }
    }

    // Calculate bearing to target point
    final dx = targetPoint.longitude - _currentPosition!.longitude;
    final dy = targetPoint.latitude - _currentPosition!.latitude;

    // Calculate angle in degrees
    return (90 - math.atan2(dy, dx) * 180 / math.pi) % 360;
  }

  void _updateNavigationProgress() {
    if (!_navigationActive ||
        _currentPosition == null ||
        _routeManager.optimizedRoute.isEmpty) {
      return;
    }

    final selectedStop = _routeManager.optimizedRoute[_selectedStopIndex];

    // Calculate remaining distance to destination
    final remainingDistance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      selectedStop.coordinates.latitude,
      selectedStop.coordinates.longitude,
    );

    // Find appropriate step index based on remaining distance
    if (remainingDistance < 0.05) {
      // 50 meters from destination
      if (_currentStepIndex < _navigationSteps.length - 1) {
        setState(() {
          _currentStepIndex = _navigationSteps.length - 1; // Show arrival step
        });

        // Notify arrival once
        if (!_arrivalNotified) {
          _arrivalNotified = true;
        }
      }
    } else if (remainingDistance < 0.3) {
      // 300m
      if (_currentStepIndex < _navigationSteps.length - 2) {
        setState(() {
          _currentStepIndex = _navigationSteps.length - 2;
        });
      }
    } else if (remainingDistance < 0.8) {
      // 800m
      if (_currentStepIndex < _navigationSteps.length - 3) {
        setState(() {
          _currentStepIndex = _navigationSteps.length - 3;
        });
      }
    } else {
      // Find closest step by remaining distance
      for (int i = 0; i < _navigationSteps.length - 3; i++) {
        double stepDistance = _navigationSteps[i]['distance'] as double;
        if (stepDistance >= remainingDistance) {
          setState(() => _currentStepIndex = i);
          break;
        }
      }
    }

    // Only update camera if needed and not in free control mode
    if (!_cameraAnimationInProgress && !_freeMapControl) {
      _animateToCurrentLocationWithHeading();
    }
  }

  void _notifyOfUpcomingTurn() {
    // Simple vibration feedback
    HapticFeedback.mediumImpact();

    // Show visual feedback
    setState(() {
      _showingTurnAlert = true;
    });
  }

  // Add after line 717, right after _notifyOfUpcomingTurn() method
  @override
  Widget build(BuildContext context) {
    // Get optimized route for UI
    final optimizedStops = _routeManager.optimizedRoute;
    final selectedStop =
        optimizedStops.isNotEmpty && _selectedStopIndex < optimizedStops.length
        ? optimizedStops[_selectedStopIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ruta dostave (${optimizedStops.length} lokacija)',
          style: GoogleFonts.inter(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _freeMapControl ? Icons.follow_the_signs : Icons.explore,
            ),
            onPressed: () {
              setState(() {
                _freeMapControl = !_freeMapControl;
                if (!_freeMapControl && _navigationActive) {
                  _animateToCurrentLocationWithHeading();
                }
              });
            },
            tooltip: _freeMapControl
                ? 'Uključi praćenje'
                : 'Slobodno kretanje mape',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _animateToCurrentLocation,
            tooltip: 'Moja lokacija',
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: _fitAllMarkers,
            tooltip: 'Prikaži cijelu rutu',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(43.8563, 18.4131), // Default: Sarajevo
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              print("Map created successfully!");
              _controller.complete(controller);
              setState(() => _mapReady = true);

              // If we already have positions, update the map
              if (_mapReady && _currentPosition != null) {
                Future.delayed(Duration(milliseconds: 500), _fitAllMarkers);
              }
            },
            onCameraMove: (CameraPosition position) {
              // Detect manual camera movement
              if (!_cameraAnimationInProgress && !_freeMapControl) {
                setState(() => _freeMapControl = true);
              }
            },
            onCameraMoveStarted: () {
              // User started moving the camera manually
              setState(() {
                _showLocationButton = true;
              });
            },
          ),

          // Return to navigation button (when in free control mode)
          if (_showLocationButton && (_freeMapControl || !_navigationActive))
            Positioned(
              right: 16,
              bottom: 240,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _freeMapControl = false;
                    _showLocationButton = false;
                  });
                  _animateToCurrentLocationWithHeading();
                },
                child: Icon(Icons.my_location, color: Colors.blue),
              ),
            ),

          // Turn notification overlay
          if (_navigationActive && _showingTurnAlert)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _navigationSteps.isNotEmpty
                            ? _navigationSteps[_currentStepIndex]['icon']
                                  as IconData
                            : Icons.info,
                        color: Colors.white,
                        size: 36,
                      ),
                      SizedBox(height: 8),
                      Text(
                        _navigationSteps.isNotEmpty
                            ? _navigationSteps[_currentStepIndex]['instruction']
                                  as String
                            : "Pratite rutu",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Fallback button
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  if (_loading &&
                      DateTime.now()
                              .difference(
                                DateTime.fromMillisecondsSinceEpoch(0),
                              )
                              .inSeconds >
                          5)
                    ElevatedButton(
                      onPressed: _enableDemoMode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: Text(
                        "GPS ne radi? Pokreni demo mod",
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                    ),

                  // Debug info for developers
                  if (_loading)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Google Maps API status: $_statusMessage\n"
                        "Map initialized: $_mapReady\n"
                        "Current position: ${_currentPosition?.toString() ?? 'None'}\n"
                        "Stops: ${optimizedStops.length}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom info panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Current destination info
                  if (selectedStop != null)
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedStop.order.kupac.naziv,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedStop.order.kupac.adresa,
                                style: GoogleFonts.inter(
                                  color: Colors.grey.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${_selectedStopIndex + 1}/${optimizedStops.length}",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      "Nema odabranih destinacija",
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),

                  const SizedBox(height: 12),

                  // Route summary
                  if (_totalDistance > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🚗 Ukupno: ${_totalDistance.toStringAsFixed(1)} km',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '⏱️ $_totalEstimatedTime',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                      ],
                    )
                  else
                    Text(
                      _statusMessage,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    ),

                  // Navigation buttons
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (!_navigationActive)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: selectedStop != null
                                ? _startNavigation
                                : null,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: Icon(Icons.navigation, size: 20),
                            label: Text("POKRENI NAVIGACIJU"),
                          ),
                        )
                      else
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _stopNavigation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: Icon(Icons.stop, size: 20),
                            label: Text("ZAUSTAVI NAVIGACIJU"),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (!_navigationActive && optimizedStops.length > 1)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedStopIndex =
                                  (_selectedStopIndex + 1) %
                                  optimizedStops.length;
                              _updateSelectedStopMarkers();
                            });
                            _focusOnSelectedStop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                          ),
                          child: const Icon(Icons.navigate_next),
                        ),
                      if (_navigationActive)
                        ElevatedButton(
                          onPressed: () {
                            // Toggle between showing the current step and showing the arrival step
                            setState(() {
                              if (_currentStepIndex ==
                                  _navigationSteps.length - 1) {
                                _currentStepIndex = math.max(
                                  0,
                                  _currentStepIndex - 2,
                                );
                              } else {
                                _currentStepIndex = _navigationSteps.length - 1;
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                          ),
                          child: const Icon(Icons.visibility),
                        ),
                    ],
                  ),

                  // Navigation instructions panel
                  if (_navigationActive && _navigationSteps.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _navigationSteps[_currentStepIndex]['icon']
                                  as IconData,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _navigationSteps[_currentStepIndex]['instruction']
                                      as String,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (_navigationSteps[_currentStepIndex]['distance'] >
                                    0)
                                  Text(
                                    'za ${(_navigationSteps[_currentStepIndex]['distance'] as double).toStringAsFixed(1)} km',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey.shade300,
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_loading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
