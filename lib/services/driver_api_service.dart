import 'dart:convert';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class DriverApiService {
  static const String baseUrl = "http://10.0.2.2/appinternal/api";
  // Add these methods to your existing driver_api_service.dart

  // Accept order and start tracking
  static Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    return await post('driver_confirm_order.php', {
      'oid': orderId.toString(),
      'action': 'accept',
    });
  }

  // Complete order
  static Future<Map<String, dynamic>> completeOrder(int orderId) async {
    return await post('driver_confirm_order.php', {
      'oid': orderId.toString(),
      'action': 'complete',
    });
  }

  // Check for box conflicts
  static Future<Map<String, dynamic>> checkConflict(
    int orderId,
    int boxNumber,
  ) async {
    return await post('driver_check_conflict.php', {
      'oid': orderId.toString(),
      'box_number': boxNumber.toString(),
    });
  }

  // Sync activity logs
  static Future<Map<String, dynamic>> syncActivityLog(
    Map<String, dynamic> logData,
  ) async {
    return await post('sync_logs.php', logData);
  }

  // Discard conflicted box
  static Future<Map<String, dynamic>> discardBox(
    int orderId,
    int boxNumber,
    String reason,
  ) async {
    return await post('sync_boxes.php', {
      'action': 'discard',
      'oid': orderId.toString(),
      'box_number': boxNumber.toString(),
      'reason': reason,
    });
  }

  // Save location data
  static Future<Map<String, dynamic>> saveLocation(
    List<Map<String, dynamic>> locations,
  ) async {
    return await post('save_location.php', {
      'locations': jsonEncode(locations), // Convert list to JSON string
    });
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    // Get session data
    final SessionManager sessionManager = SessionManager();
    final userData = await sessionManager.getUser();

    // Add authentication data to every request
    if (userData != null) {
      data['kup_id'] = userData['kup_id'].toString();
      data['pos_id'] = userData['pos_id'].toString();
      data['hash1'] = userData['hash1'];
      data['hash2'] = userData['hash2'];
    }

    final url = Uri.parse('$baseUrl/$endpoint');
    try {
      // Log what we're sending (for debugging)
      print('Sending to $endpoint: ${jsonEncode(data)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        }, // Changed this
        body: data, // Changed to send as form data, not JSON
      );

      print('Response from $endpoint: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': 0,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error in $endpoint: $e');
      return {'success': 0, 'message': 'API error: $e'};
    }
  }

  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Future<Map<String, dynamic>> fetchOrder(String code) async {
    // Check if we're online
    if (!await isOnline()) {
      // Try to extract order ID from the code
      RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
      final match = regex.firstMatch(code);
      if (match == null) {
        return {
          'success': 0,
          'message': 'Invalid barcode format and no internet connection',
        };
      }

      final oid = int.parse(match.group(2)!);

      // Check local storage
      final offlineService = OfflineService();
      final localOrder = await offlineService.getOrder(oid);

      if (localOrder != null) {
        return {'success': 1, 'order': localOrder, 'offline': true};
      }

      return {
        'success': 0,
        'message': 'No internet connection and order not found locally',
      };
    }

    // Continue with your existing online implementation
    return await post('driver_order.php', {'code': code});
  }

  static Future<Map<String, dynamic>> scanBox(String code, int oid) async {
    return await post('driver_scan_box.php', {'code': code, 'oid': oid});
  }

  static Future<Map<String, dynamic>> confirmDelivery(int oid) async {
    return await post('driver_confirm_delivery.php', {'oid': oid});
  }
}
