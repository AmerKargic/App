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

  Future<Map<String, dynamic>> getProductByBarcode(String barcode) async {
    final url = Uri.parse('$baseUrl/api/get_product.php?ean=$barcode');
    final response = await http.get(url);

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
    final url = Uri.parse(
      '$baseUrl/api/save_wishstock.php',
    ); // Adjust file name

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'aid': '$aid',
        'kup_id': '$kupId',
        'pos_id': '$posId',
        'stock_wish': '$stockWish',
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
}
