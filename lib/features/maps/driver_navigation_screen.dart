import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverNavigationScreen extends StatefulWidget {
  final String address;
  final String customerName;
  final String orderId;

  const DriverNavigationScreen({
    Key? key,
    required this.address,
    required this.customerName,
    required this.orderId,
  }) : super(key: key);

  @override
  State<DriverNavigationScreen> createState() => _DriverNavigationScreenState();
}

class _DriverNavigationScreenState extends State<DriverNavigationScreen>
    with WidgetsBindingObserver {
  final Completer<GoogleMapController> _controller = Completer();
  final loc.Location _location = loc.Location();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  bool _loading = true;
  String _statusMessage = "Učitavanje...";
  double _distance = 0;
  String _estimatedTime = "";
  bool _mapReady = false;

  // Navigation variables
  Map<String, dynamic>? _directionsData;
  bool _navigationActive = false;
  List<Map<String, dynamic>> _navigationSteps = [];
  int _currentStepIndex = 0;
  Timer? _navigationTimer;
  bool _cameraAnimationInProgress = false;
  DateTime _lastRouteUpdate = DateTime.now().subtract(Duration(minutes: 1));
  bool _freeMapControl = false;
  bool _showLocationButton = true;
  bool _arrivalNotified = false;
  bool _showingTurnAlert = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();

    // Add API key test
    Future.delayed(Duration.zero, () {
      print("Testing Google Maps API Key...");
      final testUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=Sarajevo&key=AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo',
      );
      http.get(testUrl).then((response) {
        print("API Test Response Status: ${response.statusCode}");
        if (response.statusCode == 200) {
          print("API Key works!");
        } else {
          print("API Key error: ${response.body}");
        }
      });
    });

    // Add timeout for loading state
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _loading) {
        setState(() {
          _statusMessage = "Vrijeme isteklo. Provjerite GPS postavke.";
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background, reduce update frequency
      _navigationTimer?.cancel();
      _navigationTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        if (mounted && _navigationActive) _updateNavigationProgress();
      });
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground, restore update frequency
      _navigationTimer?.cancel();
      _navigationTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
        if (mounted && _navigationActive) _updateNavigationProgress();
      });
    }
  }

  Future<void> _initialize() async {
    await _requestPermissions();
    await _getLocationUpdates();
    await _geocodeDestination();
    await _checkEmulatorAndFallback();
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
            ),
          );

          // Only update route when not in navigation and significant time passed (10 seconds)
          if (!_navigationActive &&
              _destinationPosition != null &&
              _mapReady &&
              DateTime.now().difference(_lastRouteUpdate).inSeconds > 10) {
            _lastRouteUpdate = DateTime.now();
            _updateRoute();
          }

          // Update navigation when active
          if (_navigationActive &&
              !_cameraAnimationInProgress &&
              !_freeMapControl) {
            _animateToCurrentLocationWithHeading();
          }
        });
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

        if (_mapReady && _destinationPosition != null) {
          _updateRoute();
        }
      });
    }
  }

  void _enableDemoMode() {
    // Create demo coordinates
    final demoCurrentPos = const LatLng(43.8563, 18.4131); // Sarajevo center
    final demoDestPos = LatLng(
      43.8563 + (math.Random().nextDouble() - 0.5) * 0.01,
      18.4131 + (math.Random().nextDouble() - 0.5) * 0.01,
    ); // Random location nearby

    setState(() {
      _currentPosition = demoCurrentPos;
      _destinationPosition = demoDestPos;

      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: demoCurrentPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: "Vaša lokacija (demo)"),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: demoDestPos,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.customerName,
            snippet: widget.address,
          ),
        ),
      );

      // Create a polyline between the points
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: [demoCurrentPos, demoDestPos],
          width: 5,
        ),
      );

      // Calculate distance
      _distance = _calculateDistance(
        demoCurrentPos.latitude,
        demoCurrentPos.longitude,
        demoDestPos.latitude,
        demoDestPos.longitude,
      );

      // Estimate time
      final hours = _distance / 40; // 40 km/h average speed
      final minutes = (hours * 60).round();
      _estimatedTime = "${minutes} min";

      _loading = false;
      _mapReady = true;
      _statusMessage = "Demo način rada aktiviran";
    });

    // Force map to show both markers
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_controller.isCompleted) {
        _fitBounds();
      }
    });
  }

  Future<void> _geocodeDestination() async {
    setState(() => _statusMessage = "Pronalazim lokaciju kupca...");

    try {
      // Use Google Geocoding API to convert address to coordinates
      final String encodedAddress = Uri.encodeComponent(widget.address);
      final String apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo";

      final Uri geocodingUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'address=$encodedAddress&'
        'key=$apiKey',
      );

      final response = await http.get(geocodingUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["results"].isNotEmpty) {
          final location = data["results"][0]["geometry"]["location"];
          final lat = location["lat"];
          final lng = location["lng"];

          setState(() {
            _destinationPosition = LatLng(lat, lng);

            _markers.add(
              Marker(
                markerId: const MarkerId('destination'),
                position: _destinationPosition!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
                infoWindow: InfoWindow(
                  title: widget.customerName,
                  snippet: widget.address,
                ),
              ),
            );

            _statusMessage = "Lokacija pronađena, izračunavam rutu...";

            if (_currentPosition != null && _mapReady) {
              _updateRoute();
              _fitBounds();
            }
          });
        } else {
          throw Exception("Geocoding failed: ${data["status"]}");
        }
      } else {
        throw Exception("Geocoding request failed");
      }
    } catch (e) {
      print("Error geocoding address: $e");
      setState(() {
        _statusMessage = "Greška pri pronalaženju adrese: $e";
        _loading = false;
      });
    }
  }

  Future<void> _updateRoute() async {
    if (_currentPosition == null || _destinationPosition == null) return;

    setState(() => _statusMessage = "Izračunavam rutu...");

    try {
      // Use Google Directions API
      final String origin =
          "${_currentPosition!.latitude},${_currentPosition!.longitude}";
      final String destination =
          "${_destinationPosition!.latitude},${_destinationPosition!.longitude}";
      final String apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo";

      final Uri directionsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'mode=driving&'
        'key=$apiKey',
      );

      final response = await http.get(directionsUrl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _directionsData = data;

        if (data["status"] == "OK") {
          final routes = data["routes"];

          if (routes.isNotEmpty) {
            // IMPORTANT CHANGE: Build a DETAILED polyline from all steps
            List<LatLng> detailedPolylineCoordinates = [];

            final legs = routes[0]["legs"];
            if (legs.isNotEmpty) {
              // Get distance and duration from the response
              final distanceValue = legs[0]["distance"]["value"] / 1000.0;
              final distanceText = legs[0]["distance"]["text"];
              final durationMinutes = (legs[0]["duration"]["value"] / 60)
                  .round();
              final durationText = legs[0]["duration"]["text"];

              // Get all steps to build detailed polyline
              final steps = legs[0]["steps"];

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

              setState(() {
                _distance = distanceValue;
                _estimatedTime = "$durationMinutes min";

                // Create polyline with the DETAILED route points that follow roads
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
                    "Ruta izračunata: $distanceText, $durationText";
                _loading = false;
              });

              _fitBounds();
              return;
            }
          }
        } else {
          print("Directions API error: ${data["status"]}");
          setState(() {
            _statusMessage = "API greška: ${data["status"]}";
          });
        }
      }

      // If we reach here, something went wrong with the API call
      _fallbackToStraightLine();
    } catch (e) {
      print("Error calculating route: $e");
      setState(() {
        _statusMessage = "Greška pri izračunu rute: $e";
      });

      // Fall back to straight line
      _fallbackToStraightLine();
    }
  }

  void _fallbackToStraightLine() {
    // Fall back to straight line calculation if directions API fails
    final points = [_currentPosition!, _destinationPosition!];

    setState(() {
      // Calculate straight-line distance
      _distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );

      // Estimate time (very rough - assumes 40km/h average speed)
      final hours = _distance / 40;
      final minutes = (hours * 60).round();
      _estimatedTime = "${minutes} min";

      // Create a straight line polyline
      _polylines.clear();
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.blue,
          points: points,
          width: 5,
        ),
      );

      _statusMessage = "Ruta izračunata (zračna linija)";
      _loading = false;
    });

    _fitBounds();
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        (0.5 * math.cos((lat2 - lat1) * p)) +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p));

    // Distance in km
    return 12742 *
        math.asin(math.sqrt(a)); // 2 * R * asin(sqrt(a)), R = 6371 km
  }

  Future<void> _animateToCurrentLocation() async {
    if (_currentPosition == null || !_controller.isCompleted) return;

    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15));
  }

  Future<void> _fitBounds() async {
    if (_currentPosition == null ||
        _destinationPosition == null ||
        !_controller.isCompleted)
      return;

    final controller = await _controller.future;

    // Create a bounds that includes both points
    final southwest = LatLng(
      _currentPosition!.latitude < _destinationPosition!.latitude
          ? _currentPosition!.latitude
          : _destinationPosition!.latitude,
      _currentPosition!.longitude < _destinationPosition!.longitude
          ? _currentPosition!.longitude
          : _destinationPosition!.longitude,
    );

    final northeast = LatLng(
      _currentPosition!.latitude > _destinationPosition!.latitude
          ? _currentPosition!.latitude
          : _destinationPosition!.latitude,
      _currentPosition!.longitude > _destinationPosition!.longitude
          ? _currentPosition!.longitude
          : _destinationPosition!.longitude,
    );

    // Add some padding around the bounds
    final bounds = LatLngBounds(southwest: southwest, northeast: northeast);
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _launchGoogleMapsNavigation() async {
    if (_destinationPosition == null) return;

    // Format coordinates for Google Maps
    final String destination =
        "${_destinationPosition!.latitude},${_destinationPosition!.longitude}";

    // Create URL for navigation (this opens turn-by-turn navigation directly)
    final Uri navigationUri = Uri.parse(
      'google.navigation:q=$destination&mode=d',
    );

    // Try launching Google Maps app
    if (await canLaunchUrl(navigationUri)) {
      await launchUrl(navigationUri);
    } else {
      // Fallback to web URL if app isn't installed
      final Uri webUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destination&travelmode=driving',
      );

      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      } else {
        // Show error if both attempts fail
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ne mogu pokrenuti Google Maps navigaciju')),
          );
        }
      }
    }
  }

  void _startInAppNavigation() {
    if (_destinationPosition == null || _currentPosition == null) return;

    // Start navigation mode
    setState(() {
      _navigationActive = true;
      _freeMapControl = false; // Reset to auto-follow when starting navigation
      _statusMessage = "Navigacija aktivna...";
    });

    // Extract navigation steps from the directions API response
    _extractNavigationSteps();

    // Animate camera to follow current position with heading
    _animateToCurrentLocationWithHeading();

    // Use a more efficient timer strategy
    _navigationTimer?.cancel();
    _navigationTimer = Timer.periodic(Duration(milliseconds: 1500), (timer) {
      if (mounted && _navigationActive) {
        _updateNavigationProgress();
      }
    });
  }

  void _notifyOfUpcomingTurn() {
    // Simple vibration feedback
    HapticFeedback.mediumImpact();

    // Show visual feedback
    setState(() {
      _showingTurnAlert = true;
    });

    // Hide after 3 seconds
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showingTurnAlert = false;
        });
      }
    });
  }

  void _showArrivalNotification() {
    // Play arrival sound if you have audio plugin

    // Show snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        duration: Duration(seconds: 5),
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Stigli ste na odredište!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDefaultNavigationSteps() {
    setState(() {
      _navigationSteps = [
        {
          'instruction': 'Krenite prema odredištu',
          'distance': _distance,
          'maneuver': 'start',
          'icon': Icons.arrow_upward,
        },
        {
          'instruction': 'Pratite rutu',
          'distance': _distance * 0.5,
          'maneuver': 'straight',
          'icon': Icons.straight,
        },
        {
          'instruction': 'Približavate se odredištu',
          'distance': _distance * 0.2,
          'maneuver': 'approaching',
          'icon': Icons.location_searching,
        },
        {
          'instruction': 'Stigli ste na odredište',
          'distance': 0.0,
          'maneuver': 'arrive',
          'icon': Icons.location_on,
        },
      ];
      _currentStepIndex = 0;
    });
  }

  void _extractNavigationSteps() {
    if (_directionsData != null && _directionsData!["routes"].isNotEmpty) {
      final steps = _directionsData!["routes"][0]["legs"][0]["steps"];

      // Add markers for major turns
      _markers.removeWhere(
        (marker) => marker.markerId.value.startsWith('waypoint_'),
      );

      int waypointIndex = 1;
      for (var step in steps) {
        // Only add markers for turns, not every step
        if (step["maneuver"] != null &&
            (step["maneuver"].toString().contains("turn") ||
                step["maneuver"].toString().contains("roundabout"))) {
          final lat = step["start_location"]["lat"];
          final lng = step["start_location"]["lng"];

          _markers.add(
            Marker(
              markerId: MarkerId('waypoint_$waypointIndex'),
              position: LatLng(lat, lng),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
              infoWindow: InfoWindow(
                title: step["html_instructions"].toString().replaceAll(
                  RegExp(r'<[^>]*>'),
                  ' ',
                ),
              ),
              // Make waypoint markers smaller than main markers
              zIndex: 1, // Lower than main markers
            ),
          );

          waypointIndex++;
        }
      }

      try {
        final routes = _directionsData!["routes"];
        if (routes.isEmpty) {
          _setDefaultNavigationSteps();
          return;
        }

        final legs = routes[0]["legs"];
        if (legs.isEmpty) {
          _setDefaultNavigationSteps();
          return;
        }

        final steps = legs[0]["steps"];
        if (steps == null || steps.isEmpty) {
          _setDefaultNavigationSteps();
          return;
        }

        // Parse the actual steps from the API
        List<Map<String, dynamic>> navigationSteps = [];

        // Add starting instruction
        navigationSteps.add({
          'instruction': 'Krećete prema odredištu',
          'distance': legs[0]["distance"]["value"] / 1000.0,
          'maneuver': 'start',
          'icon': Icons.arrow_upward,
        });

        // Process each step from the API
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
        navigationSteps.add({
          'instruction': 'Stigli ste na odredište',
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

  // Replace the _getHeadingToDestination method with this improved version
  double _getHeadingToDestination() {
    if (_currentPosition == null || _destinationPosition == null) return 0;

    // Find the closest point on the polyline to our current position
    LatLng targetPoint = _destinationPosition!;

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
        _destinationPosition == null)
      return;

    // Cache calculations to avoid redundant work
    double lastDistance = -1;
    final remainingDistance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _destinationPosition!.latitude,
      _destinationPosition!.longitude,
    );

    // Only update if distance changed significantly (10 meters)
    if (lastDistance == -1 || (lastDistance - remainingDistance).abs() > 0.01) {
      lastDistance = remainingDistance;

      // Find appropriate step index
      int newStepIndex = _currentStepIndex;

      if (remainingDistance < 0.05) {
        newStepIndex = _navigationSteps.length - 1; // Arrival

        // Show arrival notification once
        if (!_arrivalNotified &&
            _currentStepIndex != _navigationSteps.length - 1) {
          _arrivalNotified = true;
          _showArrivalNotification();
        }
      } else if (remainingDistance < 0.3) {
        newStepIndex = math.max(_navigationSteps.length - 2, 0);
      } else if (remainingDistance < 0.8) {
        newStepIndex = math.max(_navigationSteps.length - 3, 0);
      } else {
        // Find closest step by remaining distance
        for (int i = 0; i < _navigationSteps.length - 1; i++) {
          double stepDistance = _navigationSteps[i]['distance'] as double;
          if (stepDistance >= remainingDistance) {
            newStepIndex = i;
            break;
          }
        }
      }

      // Only update state if step changed
      if (newStepIndex != _currentStepIndex) {
        // Notify of upcoming turn if it's a turning maneuver
        final maneuver =
            _navigationSteps[newStepIndex]['maneuver'] as String? ?? '';
        if (maneuver.contains('turn') || maneuver.contains('roundabout')) {
          _notifyOfUpcomingTurn();
        }

        setState(() => _currentStepIndex = newStepIndex);
      }
    }

    // Only update camera if needed and not in free control mode
    if (!_cameraAnimationInProgress && !_freeMapControl) {
      _animateToCurrentLocationWithHeading();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _navigationTimer?.cancel();
    _controller.future
        .then((controller) => controller.dispose())
        .catchError((_) {});
    _markers.clear();
    _polylines.clear();
    _directionsData = null;
    _navigationSteps.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Navigacija - #${widget.orderId}',
          style: GoogleFonts.inter(),
        ),
        actions: [
          // Toggle free map control button
          IconButton(
            icon: Icon(
              _freeMapControl ? Icons.follow_the_signs : Icons.explore,
            ),
            onPressed: () {
              setState(() {
                _freeMapControl = !_freeMapControl;
                if (!_freeMapControl && _navigationActive) {
                  // If returning to auto-follow mode, move camera back to current position
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
            onPressed: _fitBounds,
            tooltip: 'Prikaži cijelu rutu',
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: _launchGoogleMapsNavigation,
            tooltip: 'Google Maps',
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
              if (_currentPosition != null && _destinationPosition != null) {
                _updateRoute();
                Future.delayed(Duration(milliseconds: 500), _fitBounds);
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
          if (_showingTurnAlert)
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
                        _navigationSteps[_currentStepIndex]['icon'] as IconData,
                        color: Colors.white,
                        size: 36,
                      ),
                      SizedBox(height: 8),
                      Text(
                        _navigationSteps[_currentStepIndex]['instruction']
                            as String,
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
                        "Destination: ${_destinationPosition?.toString() ?? 'None'}",
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
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.customerName,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.address,
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_distance > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🚗 ${_distance.toStringAsFixed(1)} km',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '⏱️ $_estimatedTime',
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
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _destinationPosition != null
                              ? (_navigationActive
                                    ? null
                                    : _startInAppNavigation)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navigationActive
                                ? Colors.green
                                : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: Icon(
                            _navigationActive
                                ? Icons.gps_fixed
                                : Icons.navigation,
                            size: 20,
                          ),
                          label: Text(
                            _navigationActive
                                ? "NAVIGACIJA AKTIVNA"
                                : "POKRENI NAVIGACIJU",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _launchGoogleMapsNavigation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                            horizontal: 8,
                          ),
                        ),
                        child: const Icon(Icons.map),
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
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _navigationActive = false;
                                _navigationTimer?.cancel();
                              });
                              _fitBounds(); // Show full route again
                            },
                            icon: const Icon(Icons.close, color: Colors.white),
                            tooltip: 'Zaustavi navigaciju',
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
