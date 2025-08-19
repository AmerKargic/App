import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:flutter/material.dart';

import 'product_model.dart';

// ...existing code...
class ProductListController extends ChangeNotifier {
  final ApiService apiService;
  final int kupId;
  final int posId; // legacy (ignorira se)

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = false;
  String? _error;

  // Dozvole
  bool fullAccess = false;
  List<String> allowedMagacini = []; // prazno = full access

  List<Product> get products => _filteredProducts;
  bool get loading => _loading;
  String? get error => _error;

  ProductListController({
    required this.apiService,
    required this.kupId,
    required this.posId,
  });

  Future<void> _loadAllowedMagacini() async {
    allowedMagacini = [];
    fullAccess = false;
    try {
      final user = await SessionManager().getUser();
      Map<String, dynamic>? options = user?['options'];

      // 🔥 PRVO POKUŠAJ getUserPermissions (ali ignoriraj ako fail)
      try {
        final perm = await ApiService.getUserPermissions();
        if (perm['success'] == 1) {
          options = perm['data']?['options'] ?? options;
        }
      } catch (_) {
        print('⚠️ getUserPermissions failed, using session options');
      }

      if (options != null) {
        // 🔥 ISPRAVKA: oba moraju biti == 1 za full access
        fullAccess =
            (options['PristupProknjizi'] == 1) &&
            (options['pravo_pregleda_svihmpkomercs'] == 1);

        // 🔥 AKO NEMA FULL ACCESS, UZMI MAGACINE IZ ARRAY
        if (!fullAccess) {
          final mArr = options['Magacini_ID_array'] as Map<String, dynamic>?;
          if (mArr != null && mArr.isNotEmpty) {
            allowedMagacini = mArr.keys.map((e) => e.toString()).toList();
          }
        }
      }

      // 🔥 UKLONI OVO - NE TRETIRAJ PRAZNO KAO FULL ACCESS!
      // if (allowedMagacini.isEmpty) {
      //   fullAccess = true;
      // }

      print(
        '🔐 Permissions FIXED: fullAccess=$fullAccess allowedMagacini=$allowedMagacini',
      );
    } catch (e) {
      print('⚠️ permissions error: $e');
      // 🔥 FALLBACK: bez full access, prazan magacini = nema pristupa
      fullAccess = false;
      allowedMagacini = [];
    }
  }

  bool canEditWishStock(WishStock ws) {
    if (ws.isLocked) return false;
    if (fullAccess) return true;
    return allowedMagacini.contains(ws.magId);
  }

  Future<void> fetchProducts() async {
    _loading = true;
    notifyListeners();

    await _loadAllowedMagacini();

    try {
      // 🔥 POŠALJI MAGACINE SAMO AKO IH IMAŠ
      final resp = await apiService.getProductsByMagacini(
        magaciniIds: allowedMagacini.isNotEmpty ? allowedMagacini : null,
      );

      if (resp['success'] != 1) {
        _error = resp['message'] ?? 'Neuspješan dohvat';
        _allProducts = [];
        _filteredProducts = [];
      } else {
        final list = (resp['data'] ?? resp['products'] ?? []) as List;
        _allProducts = list.map((e) => Product.fromJson(e)).toList();

        // 🔥 LOKALNO FILTRIRANJE SAMO AKO NIJE FULL ACCESS
        if (!fullAccess && allowedMagacini.isNotEmpty) {
          _allProducts = _allProducts.map((p) {
            final filtered = p.wishstock
                .where((w) => allowedMagacini.contains(w.magId))
                .toList();
            return p.copyWith(wishstock: filtered);
          }).toList();
        }

        _filteredProducts = _allProducts;
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
      _allProducts = [];
      _filteredProducts = [];
    }

    _loading = false;
    notifyListeners();
  }

  void search(String value) {
    if (value.isEmpty) {
      _filteredProducts = _allProducts;
    } else {
      final q = value.toLowerCase();
      _filteredProducts = _allProducts.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.ean.contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q);
      }).toList();
    }
    notifyListeners();
  }
}
