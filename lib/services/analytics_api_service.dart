import 'dart:convert';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:http/http.dart' as http;

class AnalyticsApiService {
  static const String baseUrl =
      "https://www.digitalis.ba/webshop/appinternal/api";
  // "http://10.0.2.2/appinternal/api";

  /// Get real-time dashboard statistics
  Future<Map<String, dynamic>> getRealtimeStats() async {
    return await _post('analytics/realtime_stats.php', {});
  }

  /// Get driver performance analytics
  Future<Map<String, dynamic>> getDriverPerformance({
    int? driverId,
    DateTime? from,
    DateTime? to,
  }) async {
    return await _post('analytics/driver_performance.php', {
      if (driverId != null) 'driver_id': driverId.toString(),
      if (from != null) 'from_date': from.toIso8601String(),
      if (to != null) 'to_date': to.toIso8601String(),
    });
  }

  /// Get delivery time analytics
  // Future<Map<String, dynamic>> getDeliveryTimeAnalytics({
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/delivery_times.php', {
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  /// Get route efficiency data
  // Future<Map<String, dynamic>> getRouteEfficiency({
  //   int? driverId,
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/route_efficiency.php', {
  //     if (driverId != null) 'driver_id': driverId.toString(),
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  /// Get customer satisfaction metrics
  // Future<Map<String, dynamic>> getCustomerSatisfaction({
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/customer_satisfaction.php', {
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  /// Get delivery heat map data
  // Future<Map<String, dynamic>> getDeliveryHeatMap({
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/delivery_heatmap.php', {
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  // /// Get peak hours analysis
  // Future<Map<String, dynamic>> getPeakHoursAnalysis({
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/peak_hours.php', {
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  /// Get driver comparison data
  // Future<Map<String, dynamic>> getDriverComparison({
  //   List<int>? driverIds,
  //   DateTime? from,
  //   DateTime? to,
  // }) async {
  //   return await _post('analytics/driver_comparison.php', {
  //     if (driverIds != null) 'driver_ids': driverIds.join(','),
  //     if (from != null) 'from_date': from.toIso8601String(),
  //     if (to != null) 'to_date': to.toIso8601String(),
  //   });
  // }

  /// Get predictive analytics
  // Future<Map<String, dynamic>> getPredictiveAnalytics() async {
  //   return await _post('analytics/predictive.php', {});
  // }

  /// Private method to handle API calls
  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      // Get session data
      final SessionManager sessionManager = SessionManager();
      final userData = await sessionManager.getUser();

      // Add authentication data
      if (userData != null) {
        data['kup_id'] = userData['kup_id'].toString();
        data['pos_id'] = userData['pos_id'].toString();
        data['hash1'] = userData['hash1'];
        data['hash2'] = userData['hash2'];
      }

      final url = Uri.parse('$baseUrl/$endpoint');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: data,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': 0,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Analytics API error: $e');
      return {'success': 0, 'message': 'API error: $e'};
    }
  }
}
