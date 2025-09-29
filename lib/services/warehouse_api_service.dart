import 'dart:convert';
import 'package:digitalisapp/services/apo_config.dart';
import 'package:http/http.dart' as http;
import '../models/shelf.dart';
import '../models/product.dart';

class WarehouseApiService {
  //final String baseUrl; // e.g. "https://10.0.2.2/appinternal/"
  static const String baseUrl = ApiConfig.baseUrl;
  // "http://10.0.2.2/webshop/appinternal/api/";
  WarehouseApiService();
  Future<Shelf?> createShelf(String name) async {
    final url = Uri.parse('$baseUrl/add_shelf.php');

    // Generate a fake EAN for testing — replace this logic as needed
    final generatedEan = DateTime.now().millisecondsSinceEpoch
        .toString()
        .padRight(13, '0')
        .substring(0, 13);

    final response = await http.post(
      url,
      body: {'shelf_name': name, 'shelf_ean': generatedEan},
    );

    print('🔄 [createShelf] status: ${response.statusCode}');
    print('📥 [createShelf] response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == 1) {
        return Shelf(id: data['shelf_id'], name: name, barcode: generatedEan);
      } else {
        print('❌ Error creating shelf: ${data['message']}');
      }
    }
    return null;
  }

  Future<Product?> getProductByEAN(String ean) async {
    final url = Uri.parse('$baseUrl/get_product_by_ean.php');
    final response = await http.post(url, body: {'ean': ean});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == 1) {
        return Product.fromJson(data['product']);
      }
    }
    return null;
  }

  Future<bool> assignProductsToShelf(int shelfId, List<int> productIds) async {
    final url = Uri.parse('$baseUrl/add_products_to_shelf.php');
    final response = await http.post(
      url,
      body: {
        'shelf_id': shelfId.toString(),
        'product_ids': json.encode(productIds),
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == 1;
    }
    return false;
  }

  Future<Shelf?> findShelfByProduct(String ean) async {
    final url = Uri.parse('$baseUrl/find_product_shelf.php');
    final response = await http.post(url, body: {'ean': ean});
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == 1) {
        return Shelf.fromJson(data['shelf']);
      }
    }
    return null;
  }

  Future<List<ShelfProduct>> getProductsOnShelf(int shelfId) async {
    final url = Uri.parse('$baseUrl/get_shelf_products.php');
    final response = await http.post(
      url,
      body: {'shelf_id': shelfId.toString()},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == 1) {
        return (data['products'] as List)
            .map((j) => ShelfProduct.fromJson(j))
            .toList(); //26:27sss s s s ss sss ssss sssss ssssss sssssss sssssss ssssssss ssssssssss
      }
    }
    return [];
  }
}
