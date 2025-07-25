import 'dart:math' as Math;

import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeliveryStop {
  final DriverOrder order;
  final LatLng coordinates;
  bool isCompleted;

  DeliveryStop({
    required this.order,
    required this.coordinates,
    this.isCompleted = false,
  });
}

class DeliveryRouteManager {
  static final DeliveryRouteManager _instance =
      DeliveryRouteManager._internal();

  factory DeliveryRouteManager() {
    return _instance;
  }

  DeliveryRouteManager._internal();

  // All orders to be delivered
  final List<DeliveryStop> _stops = [];

  // Current optimized route
  List<DeliveryStop> _optimizedRoute = [];

  // Get all stops
  List<DeliveryStop> get allStops => List.unmodifiable(_stops);

  // Get optimized route
  List<DeliveryStop> get optimizedRoute => List.unmodifiable(_optimizedRoute);

  // Add a new stop
  // Improved addStop method with better address composition
  Future<bool> addStop(DriverOrder order) async {
    // Check if order already exists
    if (_stops.any((stop) => stop.order.oid == order.oid)) {
      return false;
    }

    // Create a more precise address string
    final kupac = order.kupac;
    final addressComponents = [
      kupac.adresa, // Street address
      kupac.opstina, // Municipality/town
      kupac.drzava, // Country
    ].where((component) => component.isNotEmpty).toList();

    final detailedAddress = addressComponents.join(", ");

    // Convert detailed address to coordinates
    final coordinates = await _geocodeAddress(detailedAddress);
    if (coordinates == null) return false;

    _stops.add(DeliveryStop(order: order, coordinates: coordinates));

    // Re-optimize route whenever a new stop is added
    await optimizeRoute();

    return true;
  }

  // Remove a stop
  void removeStop(int orderId) {
    _stops.removeWhere((stop) => stop.order.oid == orderId);
    _optimizeRouteLocally(); // Quickly update route without API call
  }

  // Mark a stop as completed
  void markStopCompleted(int orderId, bool completed) {
    final index = _stops.indexWhere((stop) => stop.order.oid == orderId);
    if (index >= 0) {
      _stops[index].isCompleted = completed;
      _optimizeRouteLocally();
    }
  }

  // Clear all stops
  void clearStops() {
    _stops.clear();
    _optimizedRoute.clear();
  }

  // Get current stop count
  int get stopCount => _stops.length;

  // Get remaining stop count (not completed)
  int get remainingStops => _stops.where((stop) => !stop.isCompleted).length;

  // Geocode an address to coordinates
  // Improved geocoding method for DeliveryRouteManager
  Future<LatLng?> _geocodeAddress(String address) async {
    try {
      final apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo";

      // Don't geocode empty addresses
      if (address.trim().isEmpty) {
        debugPrint("Warning: Empty address provided for geocoding");
        return _getFallbackCoordinates();
      }

      debugPrint("Geocoding address: $address");

      // FIXED: Use a single string without comments between parameters
      final encodedAddress = Uri.encodeComponent(address);
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedAddress&region=ba&language=bs&key=$apiKey',
      );

      // Debug the full URL to verify it's formatted correctly
      debugPrint("Geocoding URL: ${url.toString()}");

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["status"] == "OK" && data["results"].isNotEmpty) {
          final result = data["results"][0];
          final locationType = result["geometry"]["location_type"];
          final location = result["geometry"]["location"];
          final lat = location["lat"];
          final lng = location["lng"];

          // Try to find the best result by checking location type
          // ROOFTOP is the most accurate, followed by RANGE_INTERPOLATED, then GEOMETRIC_CENTER, then APPROXIMATE
          bool isHighPrecision =
              locationType == "ROOFTOP" || locationType == "RANGE_INTERPOLATED";

          // If result is not high precision but we have multiple results, try to find a better one
          if (!isHighPrecision && data["results"].length > 1) {
            for (var i = 1; i < data["results"].length; i++) {
              final altResult = data["results"][i];
              final altLocationType = altResult["geometry"]["location_type"];

              if (altLocationType == "ROOFTOP" ||
                  altLocationType == "RANGE_INTERPOLATED") {
                // Found a better result
                final altLocation = altResult["geometry"]["location"];
                debugPrint(
                  "Found better result (${altLocationType}) at index $i",
                );
                return LatLng(altLocation["lat"], altLocation["lng"]);
              }
            }
          }

          debugPrint(
            "Geocoded address with precision $locationType: $lat, $lng",
          );
          return LatLng(lat, lng);
        } else {
          debugPrint("Geocoding failed: ${data["status"]}");
        }
      }

      return _getFallbackCoordinates();
    } catch (e) {
      debugPrint("Geocoding error: $e");
      return _getFallbackCoordinates();
    }
  }

  // Add this helper method for fallback coordinates
  LatLng _getFallbackCoordinates() {
    final random = Math.Random();
    return LatLng(
      43.8563 +
          (random.nextDouble() - 0.5) *
              0.02, // Sarajevo center with ~1km offset
      18.4131 + (random.nextDouble() - 0.5) * 0.02,
    );
  }

  // Add this utility method to get stops by status
  List<DeliveryStop> getStopsByStatus(bool completed) {
    return _stops.where((stop) => stop.isCompleted == completed).toList();
  }

  // Optimize the delivery route using Google Directions API
  Future<void> optimizeRoute() async {
    if (_stops.isEmpty) return;

    // Skip optimization if there's only one stop
    if (_stops.length == 1) {
      _optimizedRoute = List.from(_stops);
      return;
    }

    try {
      // For more than 1 stop, use Directions API with waypoints
      final apiKey = "AIzaSyDfbZ7pns5PGR8YNwWIIdLqQmnNdCkQOjo";

      // Only consider undelivered stops
      final activeStops = _stops.where((stop) => !stop.isCompleted).toList();
      if (activeStops.isEmpty) {
        _optimizedRoute = [];
        return;
      }

      if (activeStops.length == 1) {
        _optimizedRoute = activeStops;
        return;
      }

      // First stop is origin, last stop is destination
      final origin =
          "${activeStops.first.coordinates.latitude},${activeStops.first.coordinates.longitude}";
      final destination =
          "${activeStops.last.coordinates.latitude},${activeStops.last.coordinates.longitude}";

      // Add intermediate stops as waypoints
      final waypoints = activeStops
          .sublist(1, activeStops.length - 1)
          .map((stop) {
            return "${stop.coordinates.latitude},${stop.coordinates.longitude}";
          })
          .join('|');

      final optimizeWaypoints = "true"; // Let Google optimize the route order

      final url = Uri.parse(
        //i'm out
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=$origin&'
        'destination=$destination&'
        'waypoints=optimize:$optimizeWaypoints|$waypoints&'
        'key=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["status"] == "OK") {
          // Get optimized waypoint order from response
          final List<dynamic> waypointOrder =
              data["routes"][0]["waypoint_order"];

          // Reorder stops based on optimized waypoint order
          List<DeliveryStop> newRoute = [];

          // Add origin (first stop)
          newRoute.add(activeStops[0]);

          // Add waypoints in optimized order
          for (int i = 0; i < waypointOrder.length; i++) {
            // +1 because the first element in activeStops is the origin
            newRoute.add(activeStops[waypointOrder[i] + 1]);
          }

          // Add destination (last stop)
          newRoute.add(activeStops[activeStops.length - 1]);

          _optimizedRoute = newRoute;
        } else {
          _optimizeRouteLocally(); // Fallback to local optimization
        }
      } else {
        _optimizeRouteLocally(); // Fallback to local optimization
      }
    } catch (e) {
      debugPrint("Route optimization error: $e");
      _optimizeRouteLocally(); // Fallback to local optimization
    }
  }

  // Simple local optimization (nearest neighbor algorithm) as fallback
  void _optimizeRouteLocally() {
    // Only optimize undelivered stops
    final activeStops = _stops.where((stop) => !stop.isCompleted).toList();
    if (activeStops.isEmpty) {
      _optimizedRoute = [];
      return;
    }

    if (activeStops.length <= 2) {
      _optimizedRoute = activeStops;
      return;
    }

    // Start with first stop
    List<DeliveryStop> optimized = [activeStops[0]];
    List<DeliveryStop> remaining = activeStops.sublist(1);

    // Repeatedly find nearest neighbor
    while (remaining.isNotEmpty) {
      final current = optimized.last;

      // Find nearest remaining stop
      DeliveryStop? nearest;
      double minDistance = double.infinity;

      for (final stop in remaining) {
        final distance = _calculateDistance(
          current.coordinates.latitude,
          current.coordinates.longitude,
          stop.coordinates.latitude,
          stop.coordinates.longitude,
        );

        if (distance < minDistance) {
          minDistance = distance;
          nearest = stop;
        }
      }

      if (nearest != null) {
        optimized.add(nearest);
        remaining.remove(nearest);
      }
    }

    _optimizedRoute = optimized;
  }

  // Calculate straight-line distance between coordinates
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a =
        0.5 -
        (0.5 * Math.cos((lat2 - lat1) * p)) +
        Math.cos(lat1 * p) *
            Math.cos(lat2 * p) *
            (1 - Math.cos((lon2 - lon1) * p));

    // Distance in km
    return 12742 *
        Math.asin(Math.sqrt(a)); // 2 * R * asin(sqrt(a)), R = 6371 km
  }

  void addStopWithCoordinates(DriverOrder order, LatLng coordinates) {
    // Check if order already exists
    if (_stops.any((stop) => stop.order.oid == order.oid)) {
      debugPrint("Order ${order.oid} already exists in route");
      return;
    }

    _stops.add(DeliveryStop(order: order, coordinates: coordinates));
    debugPrint(
      "Added test stop for order ${order.oid} at coordinates: $coordinates",
    );

    // Re-optimize route immediately
    _optimizeRouteLocally();
  }
}
