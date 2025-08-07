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
      'pos_id': user['pos_id'].toString(),
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
        'pos_id': posId.toString(),
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
          'pos_id': posId.toString(),
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
          'pos_id': posId.toString(),
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
}
