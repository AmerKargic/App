import 'package:digitalisapp/services/api_service.dart';
import 'package:flutter/material.dart';

import 'product_model.dart';

class ProductListController extends ChangeNotifier {
  final ApiService apiService;
  final int kupId;
  final int posId;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = false;
  String? _error;

  List<Product> get products => _filteredProducts;
  bool get loading => _loading;
  String? get error => _error;

  ProductListController({
    required this.apiService,
    required this.kupId,
    required this.posId,
  });

  Future<void> fetchProducts() async {
    _loading = true;
    notifyListeners();

    try {
      // TODO: Replace this with your real "get all products" endpoint
      // Here's a mock for dev:
      final fakeList = [
        {
          "ID": "5555",
          "EAN": "1234567890123",
          "name": "Test Artikal",
          "Brand": "@AWA",
          "MPC": "na rate: 123,45 KM",
          "MPC_jednokratno": "jednokratno: 123,45 KM",
          "description": "Opis artikla...",
          "images": [
            {
              "small":
                  "https://www.cloud-storefiles.com/static/sm/5555_1686163677tvhysz0ph7.png",
            },
          ],
          "image":
              "https://www.cloud-storefiles.com/static/sm/5555_1686163677tvhysz0ph7.png",
          "wishstock": [
            {
              "kup_id": "510",
              "pos_id": "3000",
              "mag_id": "4001",
              "name": "Test POS",
              "stock": 0,
              "stock_wish": 0,
              "stock_wish_locked": "1",
            },
          ],
        },
        // Duplicate, or make several for testing!
      ];
      _allProducts = fakeList.map((e) => Product.fromJson(e)).toList();
      _filteredProducts = _allProducts;
      _error = null;

      /* // When you get a real endpoint:
      final response = await apiService.getAllProducts(kupId, posId);
      if (response['success'] == 1 && response['data'] is List) {
        _allProducts = (response['data'] as List)
          .map((e) => Product.fromJson(e))
          .toList();
        _filteredProducts = _allProducts;
        _error = null;
      } else {
        _error = response['message'] ?? 'Unknown error';
      }
      */
    } catch (e) {
      _error = e.toString();
    }

    _loading = false;
    notifyListeners();
  }

  void search(String value) {
    if (value.isEmpty) {
      _filteredProducts = _allProducts;
    } else {
      final q = value.toLowerCase();
      _filteredProducts = _allProducts
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.ean.contains(q) ||
                p.brand.toLowerCase().contains(q) ||
                p.description.toLowerCase().contains(q),
          )
          .toList();
    }
    notifyListeners();
  }
}
