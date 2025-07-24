import 'dart:convert';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:http/http.dart' as http;
// Add this import for session data

class DriverApiService {
  static const String baseUrl = "http://10.0.2.2/appinternal/api";

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

  static Future<Map<String, dynamic>> fetchOrder(String code) async {
    return await post('driver_order.php', {'code': code});
  }

  static Future<Map<String, dynamic>> scanBox(String code, int oid) async {
    return await post('driver_scan_box.php', {'code': code, 'oid': oid});
  }

  static Future<Map<String, dynamic>> confirmDelivery(int oid) async {
    return await post('driver_confirm_delivery.php', {'oid': oid});
  }
}
