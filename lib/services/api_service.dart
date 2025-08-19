import 'dart:convert';
import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';

class ApiService {
  // static const String baseUrl = "http://10.0.2.2/webshop/appinternal";
  static const String baseUrl = "https://www.digitalis.ba/webshop/appinternal";

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/login.php');

    print("🔄 [login] Sending request to: $url");
    print("📤 [login] Payload: {email: $email, password: $password}");

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      print("📥 [login] Status code: ${response.statusCode}");
      print("📥 [login] Raw response: ${response.body}");

      if (response.statusCode == 200) {
        final data = await _handleResponse(response); // 🔥 SAMO OVO PROMIJENI

        print("✅ [login] Decoded JSON: $data");
        return data;
      } else {
        return {
          'success': false,
          'message': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print("❌ [login] Exception: $e");
      return {
        'success': false,
        'message': 'Greška prilikom povezivanja s API-jem: $e',
      };
    }
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final responseData = jsonDecode(response.body);

    // 🔥 SAMO OVA JEDNA PROVJERA
    if (responseData['force_logout'] == true) {
      print('🔥 Server requested logout: ${responseData['message']}');
      await SessionManager().clearUser();
      appLogout();
      // Ovdje možeš dodati navigaciju na login screen ako je potrebno
      throw Exception('Account disabled - logged out');
    }

    return responseData;
  }

  Future<Map<String, String>> _getSessionParams() async {
    final user = await SessionManager().getUser();
    if (user == null) return {};
    return {
      'kup_id': user['kup_id'].toString(),
      // 'pos_id': user['pos_id'].toString(),
      'hash1': user['hash1'],
      'hash2': user['hash2'],
    };
  }

  Future<Map<String, dynamic>> getProductByBarcode(
    String barcode,
    int kupId,
    int posId,
    String hash1,
    String hash2,
  ) async {
    final url = Uri.parse('$baseUrl/api/get_product.php');

    final response = await http.post(
      url,
      body: {
        'ean': barcode,
        'kup_id': kupId.toString(),
        // 'pos_id': posId.toString(),
        'hash1': hash1,
        'hash2': hash2,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    }
  }

  // ...existing code...

  Future<Map<String, dynamic>> getProductsByMagacini({
    List<String>? magaciniIds,
  }) async {
    final session = await _getSessionParams();

    try {
      // SVE VRIJEDNOSTI U BODY SU STRING!
      final body = <String, String>{
        'kup_id': session['kup_id']?.toString() ?? '',
        'hash1': session['hash1']?.toString() ?? '',
        'hash2': session['hash2']?.toString() ?? '',
        'action': 'validate_session',
        'magacini_ids': magaciniIds?.join(',') ?? '',
      };

      print('DEBUG: body=$body');

      final url = Uri.parse('$baseUrl/api/get_product.php');
      final resp = await http.post(url, body: body);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        print('🔍 [getProductsByMagacini] Response: $data');
        return data;
      }

      return {'success': 0, 'message': 'Session validation failed'};
    } catch (e) {
      print('❌ [getProductsByMagacini] Error: $e');
      return {'success': 0, 'message': 'Greška: $e'};
    }
  }

  // ...existing code...
  //wishstock update
  Future<Map<String, dynamic>> saveWishstock({
    required int aid,
    required int kupId,
    required int posId,
    required double stockWish,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/save_wishstock.php'),
        body: {
          'aid': aid.toString(),
          'kup_id': kupId.toString(),
          'pos_id': '0',
          'stock_wish': stockWish.toString(),
        },
      );
      print('RAW response: ${response.body}');

      final data = jsonDecode(response.body);

      print('Save wishstock response: $data');
      return data;
    } catch (e) {
      print('Save wishstock error: $e');
      return {'success': 0, 'message': 'Greška pri komunikaciji s API-jem.'};
    }
  }

  Future<Map<String, dynamic>> saveLockState({
    required int aid,
    required int kupId,
    required int posId,
    required int locked,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/lock_state.php'),
        body: {
          'aid': aid.toString(),
          'kup_id': kupId.toString(),
          // 'pos_id': posId.toString(),
          'stock_wish_locked': locked.toString(),
        },
      );
      print('RAW lock response: ${response.body}');
      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      print('Save lock error: $e');
      return {'success': 0, 'message': 'Greška pri zaključavanju.'};
    }
  }

  static Future<Map<String, dynamic>> getUserPermissions() async {
    final apiService = ApiService();

    try {
      final sessionParams = await apiService._getSessionParams();

      if (sessionParams.isEmpty) {
        throw Exception('No session data');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/login.php'), // 🔥 KORISTIM POSTOJEĆI login.php!
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'get_permissions', // 🔥 DODAJEM SAMO ACTION PARAMETER
          ...sessionParams,
        }),
      );

      print("📥 [getUserPermissions] Status: ${response.statusCode}");
      print("📥 [getUserPermissions] Response: ${response.body}");

      if (response.statusCode == 200) {
        return await apiService._handleResponse(response);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [getUserPermissions] Error: $e");
      return {'success': 0, 'message': 'Error getting permissions: $e'};
    }
  }

  static Future<Map<String, dynamic>> getWarehouseProducts({
    List<String>? magaciniIds,
  }) async {
    final apiService = ApiService();

    try {
      final sessionParams = await apiService._getSessionParams();

      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/get_product.php',
        ), // 🔥 KORISTIM POSTOJEĆI get_product.php!
        body: {
          'action': 'get_warehouse_products', // 🔥 DODAJEM ACTION
          'magacini_ids': magaciniIds?.join(',') ?? '',
          ...sessionParams,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [getWarehouseProducts] Error: $e");
      return {
        'success': 0,
        'message': 'Error getting products: $e',
        'products': [],
      };
    }
  }

  static Future<Map<String, dynamic>> getMagacini({
    List<String>? magaciniIds,
  }) async {
    final apiService = ApiService();

    try {
      final sessionParams = await apiService._getSessionParams();

      final response = await http.post(
        Uri.parse(
          '$baseUrl/api/get_product.php',
        ), // 🔥 KORISTIM POSTOJEĆI get_product.php!
        body: {
          'action': 'get_magacini', // 🔥 DODAJEM ACTION
          'magacini_ids': magaciniIds?.join(',') ?? '',
          ...sessionParams,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      print("❌ [getMagacini] Error: $e");
      return {
        'success': 0,
        'message': 'Error getting magacini: $e',
        'magacini': [],
      };
    }
  }

  Future<Map<String, dynamic>> getProductByAID(
    String aid,
    int kupId,
    String hash1,
    String hash2,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/get_product.php'),
      body: {
        'aid': aid,
        'kup_id': kupId.toString(),
        'hash1': hash1,
        'hash2': hash2,
      },
    );
    return jsonDecode(response.body);
  }

  // 🔥 DODAJ I saveWishstock BEZ MANUAL SESSION PARAMS:
  static Future<Map<String, dynamic>> saveWishstockNew({
    required int aid,
    required double stockWish,
    required String magacinId,
  }) async {
    final apiService = ApiService();

    try {
      final sessionParams = await apiService._getSessionParams();

      // DEBUG: Prije slanja requesta
      print(
        'DEBUG [saveWishstockNew] aid=$aid, stockWish=$stockWish, magacinId=$magacinId',
      );
      print('DEBUG [saveWishstockNew] sessionParams=$sessionParams');

      final response = await http.post(
        Uri.parse('$baseUrl/api/save_wishstock.php'),
        body: {
          'aid': aid.toString(),
          'stock_wish': stockWish.toString(),
          'pos_id': magacinId,
          'kup_id': sessionParams['kup_id'] ?? '',
          'hash1': sessionParams['hash1'] ?? '',

          'hash2': sessionParams['hash2'] ?? '',
        },
      );
      print('debug debug');
      // DEBUG: Nakon odgovora servera
      print('DEBUG [saveWishstockNew] RAW response: ${response.body}');

      final data = jsonDecode(response.body);
      print('DEBUG [saveWishstockNew] Parsed response: $data');
      return data;
    } catch (e) {
      print('DEBUG [saveWishstockNew] ERROR: $e');
      return {'success': 0, 'message': 'Greška pri komunikaciji s API-jem.'};
    }
  }
}
