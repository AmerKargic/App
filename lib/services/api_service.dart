import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2/appinternal";

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/login.php');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      print("Raw response: ${response.body}");
      return jsonDecode(response.body);
    } else {
      return {
        'success': false,
        'message': 'Server error: ${response.statusCode}',
      };
    }
  }

  Future<Map<String, dynamic>> getProductByBarcode(
    String barcode,
    int kupId,
    int posId,
  ) async {
    final url = Uri.parse('$baseUrl/api/get_product.php');

    final response = await http.post(
      url,
      body: {
        'ean': barcode,
        'kup_id': kupId.toString(),
        'pos_id': posId.toString(),
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
