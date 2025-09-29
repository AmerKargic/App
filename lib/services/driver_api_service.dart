import 'dart:async';
import 'dart:convert';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/models/user_model.dart';
import 'package:digitalisapp/services/apo_config.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';

class DriverApiService {
  static const String baseUrl = ApiConfig.baseUrl;
  // "http://10.0.2.2/webshop/appinternal/api";
  // Add these methods to your existing driver_api_service.dart
  // static const String baseUrl =
  //     "http://10.0.2.2/webshop/appinternal/api"; //ovdje dodati lokaciju endpointa

  // Accept order and start tracking
  static Future<Map<String, dynamic>> acceptOrder(int orderId) async {
    return await post('driver_confirm_order.php', {
      'oid': orderId.toString(),
      'action': 'accept',
    });
  }

  // Complete order
  // Replace your existing completeOrder method with this:
  static Future<Map<String, dynamic>> completeOrder(int orderId) async {
    print('🔍 DEBUG: completeOrder called with orderId: $orderId');

    try {
      // Get session data using the existing SessionManager
      final SessionManager sessionManager = SessionManager();
      final userData = await sessionManager.getUser();

      print('🔍 DEBUG: userData: $userData');

      if (userData == null) {
        print('🔍 DEBUG: No user data found');
        return {'success': 0, 'message': 'User session not found.'};
      }

      // 🔥 FIXED: Use the existing post method with proper data structure
      final requestData = {
        'oid': orderId.toString(), // Convert to string for consistency
        'action': 'complete',
        // Authentication data will be added automatically by the post() method
      };

      print('🔍 DEBUG: Calling post method with data: $requestData');

      // 🔥 FIXED: Use the existing post() method that handles authentication
      final response = await post('driver_confirm_order.php', requestData);

      print('🔍 DEBUG: Complete response: $response');

      // Return the response as-is since post() already handles JSON parsing
      return response;
    } catch (e) {
      print('🔍 DEBUG: Exception in completeOrder: $e');
      return {'success': 0, 'message': 'Network error: ${e.toString()}'};
    }
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
    final SessionManager sessionManager = SessionManager();
    final userData = await sessionManager.getUser();
    print('userData: $userData');
    // 🔥 DODANO: Dodaj Magacini_ID_array iz sesije ako postoji
    if (userData != null) {
      data['kup_id'] = userData['kup_id']?.toString();
      data['pos_id'] = userData['pos_id']?.toString();
      data['hash1'] = userData['hash1'];
      data['hash2'] = userData['hash2'];

      // Dodaj Magacini_ID_array iz sesije

      data['Magacini_ID_array'] = userData['Magacini_ID_array'];
    }

    final url = Uri.parse('$baseUrl/$endpoint');
    try {
      // Log what we're sending (for debugging)
      print('Sending to $endpoint: ${jsonEncode(data)}');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(data),
          )
          .timeout(
            const Duration(seconds: 15),
          ); // 🔥 DODANO: Timeout da ne visi loading

      print('Response from $endpoint: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': 0,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } on TimeoutException {
      print('Timeout in $endpoint');
      return {'success': 0, 'message': 'Request timeout'};
    } catch (e) {
      print('Error in $endpoint: $e');
      return {'success': 0, 'message': 'API error: $e'};
    }
  }

  // ...existing code...

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
    return await post('driver_order.php', {'code': code, 'oid': oid});
  }

  static Future<Map<String, dynamic>> scanBoxx(String code, int oid) async {
    return await post('driver_scan_box.php', {'code': code, 'oid': oid});
  }
  // Replace your existing cancelOrder method in DriverApiService with this:

  static Future<Map<String, dynamic>> cancelOrder(int orderId) async {
    print('🔍 DEBUG: cancelOrder called with orderId: $orderId');

    try {
      // Get session data using the existing SessionManager
      final SessionManager sessionManager = SessionManager();
      final userData = await sessionManager.getUser();

      print('🔍 DEBUG: userData: $userData');

      if (userData == null) {
        print('🔍 DEBUG: No user data found');
        return {'success': 0, 'message': 'User session not found.'};
      }

      // 🔥 FIXED: Use the existing post method with proper data structure
      final requestData = {
        'oid': orderId.toString(), // Convert to string for consistency
        'action': 'cancel',
        // Authentication data will be added automatically by the post() method
      };

      print('🔍 DEBUG: Calling post method with data: $requestData');

      // 🔥 FIXED: Use the existing post() method that handles authentication
      final response = await post('driver_confirm_order.php', requestData);

      print('🔍 DEBUG: Cancel response: $response');

      // Return the response as-is since post() already handles JSON parsing
      return response;
    } catch (e) {
      print('🔍 DEBUG: Exception in cancelOrder: $e');
      return {'success': 0, 'message': 'Network error: ${e.toString()}'};
    }
  }

  static Future<Map<String, dynamic>> confirmDelivery(int oid) async {
    return await post('driver_confirm_delivery.php', {'oid': oid});
  }

  // dodavanje funkcija za skeniranje tablica

  static Future<Map<String, dynamic>> getTruck(String plate) async {
    return await post('truck_endpoint.php', {'action': 'get', 'plate': plate});
  }

  static Future<Map<String, dynamic>> getActiveOrders() async {
    final sessionManager = SessionManager();
    final userData = await sessionManager.getUser();
    if (userData == null) return {'success': 0, 'orders': []};

    return await post('driver_order.php', {
      'action': 'get_active_orders',
      'kup_id': userData['kup_id'],
      'pos_id': userData['pos_id'],
      'hash1': userData['hash1'],
      'hash2': userData['hash2'],
    });
  }

  static Future<Map<String, dynamic>> takeTruck(
    String plate,
    int driver_id,
    String driver_name,
  ) async {
    final resp = await post('truck_endpoint.php', {
      'action': 'take',
      'plate': plate,
      'driver_id': driver_id,
      'driver_name': driver_name,
    });
    print('TAKE TRUCK RESPONSE: $resp');
    return resp;
  }

  static Future<Map<String, dynamic>> returnTruck(String plate) async {
    final response = await http.post(
      Uri.parse('truck_endpoint.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': 'return', 'plate': plate}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getDocumentsByDoc(String? docId) async {
    if (docId == null) return {'success': 0, 'message': 'Nedostaje doc_id'};
    var id = docId.trim();
    if (id.toLowerCase().startsWith('blag')) id = id.substring(4).trim();
    final m = RegExp(r'(\d+)').firstMatch(id);
    if (m != null) id = m.group(1)!;
    final response = await post('getOrderbyBlag.php', {
      'action': 'get_by_doc',
      'doc_id': id,
    });

    print('🔍 getDocumentsByDoc: response: $response');
    return response;
  }

  static Future<Map<String, dynamic>> requestRetailApproval(int orderId) async {
    return await post('retail_flow_endpoint.php', {
      'action': 'request_retail_approval',
      'oid': orderId.toString(),
    });
  }

  static Future<Map<String, dynamic>> retailScanBox(
    int oid,
    int boxNumber,
  ) async {
    final sessionManager = SessionManager();
    final userData = await sessionManager.getUser();
    if (userData == null) return {'success': 0, 'message': 'No user session.'};

    return await post('retail_flow_endpoint.php', {
      'action': 'retail_scan_box',
      'oid': oid,
      'box_number': boxNumber,
      'kup_id': userData['kup_id'],
      'pos_id': userData['pos_id'],
      'hash1': userData['hash1'],
      'hash2': userData['hash2'],
    });
  }

  static Future<Map<String, dynamic>> retailAccept(int orderId) async {
    return await post('retail_flow_endpoint.php', {
      'action': 'retail_accept',
      'oid': orderId.toString(),
    });
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final sessionManager = SessionManager();
    final userData = await sessionManager.getUser();
    print('userData: $userData');
    final data = {'action': 'get_notifications'};

    print(
      'Sending toasda retail_flow_endpoint.php: ${jsonEncode(data)}',
    ); // 🔥 ISPRAVLJENO: Typo "Zending" -> "Sending"
    return await post('retail_flow_endpoint.php', data);
  }

  // 🔥 DODANO: Nova funkcija za pending orders
  static Future<Map<String, dynamic>> getPendingForRetail() async {
    final sessionManager = SessionManager();
    final localUser = await sessionManager.getUser();
    if (localUser == null) return {'success': 0, 'message': 'Nema usera'};

    // Pozovi server da dobiješ svježe podatke
    final response = await http.post(
      Uri.parse("${ApiConfig.baseUrl}check_sesion.php"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "kup_id": localUser["kup_id"].toString(),
        "pos_id": localUser["pos_id"].toString(),
        "hash1": localUser["hash1"], // OVO JE BITNO!
        "hash2": localUser["hash2"], // OVO JE BITNO!
      }),
    );

    print('check_sesion.php response: ${response.body}');

    if (response.statusCode != 200) {
      return {'success': 0, 'message': 'Greška na serveru'};
    }

    final serverResponse = jsonDecode(response.body);
    if (serverResponse["success"] != 1 || serverResponse["data"] == null) {
      return {'success': 0, 'message': 'Nevalidna sesija'};
    }

    final options = serverResponse["data"]["options"];

    // 2. Pripremi payload za pending_for_retail
    final data = {
      'action': 'pending_for_retail',
      'Magacini_ID_array': options['Magacini_ID_array'],
      'Magacini_ID': options['Magacini_ID'],
      'kup_id': options['kup_id'].toString(),
      'pos_id': options['pos_id'].toString(),
      'hash1': localUser['hash1'], // UZMI IZ SESIJE!
      'hash2': localUser['hash2'], // UZMI IZ SESIJE!
    };

    print('Sending to retail_flow_endpoint.php: ${jsonEncode(data)}');
    final resp = await http.post(
      Uri.parse("${ApiConfig.baseUrl}retail_flow_endpoint.php"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );

    print('Response from retail_flow_endpoint.php: ${resp.body}');
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return {'success': 0, 'message': 'Greška u povlačenju pending orders'};
  }

  static Future<Map<String, dynamic>> markNotificationRead(int id) async {
    return await post('retail_flow_endpoint.php', {
      'action': 'mark_notification_read',
      'id': id.toString(),
    });
  }

  static Future<Map<String, dynamic>> completeOrderRetail(int oid) async {
    final sessionManager = SessionManager();
    final userData = await sessionManager.getUser();
    if (userData == null) return {'success': 0, 'message': 'No user session.'};

    return await post('retail_flow_endpoint.php', {
      'action': 'complete_order',
      'oid': oid,
      'kup_id': userData['kup_id'],
      'pos_id': userData['pos_id'],
      'hash1': userData['hash1'],
      'hash2': userData['hash2'],
    });
  }

  //funkcije za vracanje narudzbi u skladiste
  static Future<Map<String, dynamic>> getPendingReturns() async {
    return await post('return_flow_endpoint.php', {
      'action': 'pending_returns',
    });
  }

  static Future<Map<String, dynamic>> requestReturn(
    int oid,
    String reason, {
    String note = '',
  }) async {
    return await post('return_flow_endpoint.php', {
      'action': 'request_return',
      'oid': oid.toString(),
      'reason': reason,
      'note': note,
    });
  }

  static Future<Map<String, dynamic>> returnScanBox(
    int oid,
    int boxNumber,
  ) async {
    return await post('return_flow_endpoint.php', {
      'action': 'scan_return_box',
      'oid': oid,
      'box_number': boxNumber,
    });
  }

  static Future<Map<String, dynamic>> returnAccept(int oid) async {
    return await post('return_flow_endpoint.php', {
      'action': 'return_accept',
      'oid': oid,
    });
  }
}
