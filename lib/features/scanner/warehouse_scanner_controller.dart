// import 'package:flutter/material.dart';
// import '../../services/warehouse_api_service.dart';
// import '../../models/shelf.dart';
// import '../../models/product.dart';

// // Optional: For offline support, import Hive/sqflite here

// enum WarehouseScanMode { createShelf, organize, find }

// class WarehouseScannerController extends ChangeNotifier {
//   final WarehouseApiService api;
//   WarehouseScannerController({required this.api});

//   // CREATE SHELF
//   String shelfName = '';
//   Shelf? createdShelf;

//   // ORGANIZE
//   String scannedShelfBarcode = '';
//   int? scannedShelfId;
//   List<int> scannedProductIds = [];
//   List<String> scannedProductNames = [];
//   String errorMessage = '';
//   bool isLoading = false;

//   // FIND
//   Shelf? foundShelf;
//   List<ShelfProduct> productsOnShelf = [];

//   // 🛠️ Added safety flag
//   bool _isDisposed = false;

//   void _safeNotify() {
//     if (_isDisposed) return;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!_isDisposed) notifyListeners();
//     });
//   }

//   @override
//   void dispose() {
//     _isDisposed = true;
//     super.dispose();
//   }

//   void setShelfName(String name) {
//     shelfName = name;
//     _safeNotify();
//   }

//   Future<void> createShelf() async {
//     isLoading = true;
//     _safeNotify();
//     try {
//       createdShelf = await api.createShelf(shelfName);
//       errorMessage = createdShelf == null ? "Error creating shelf." : "";
//     } catch (e) {
//       errorMessage = e.toString();
//     }
//     isLoading = false;
//     _safeNotify();
//   }

//   Future<bool> scanShelfBarcode(String barcode) async {
//     isLoading = true;
//     _safeNotify();
//     try {
//       final shelf = await api.findShelfByProduct(barcode);
//       if (shelf != null) {
//         scannedShelfId = shelf.id;
//         scannedShelfBarcode = shelf.barcode;
//         errorMessage = '';
//         scannedProductIds.clear();
//         scannedProductNames.clear();
//         isLoading = false;
//         _safeNotify();
//         return true;
//       } else {
//         errorMessage = "Shelf not found!";
//         isLoading = false;
//         _safeNotify();
//         return false;
//       }
//     } catch (e) {
//       errorMessage = e.toString();
//       isLoading = false;
//       _safeNotify();
//       return false;
//     }
//   }

//   Future<void> addProductByEAN(String ean) async {
//     isLoading = true;
//     _safeNotify();
//     try {
//       final product = await api.getProductByEAN(ean);
//       if (product == null) {
//         errorMessage = "Product not found!";
//       } else if (scannedProductIds.contains(product.id)) {
//         errorMessage = "Already added.";
//       } else {
//         scannedProductIds.add(product.id);
//         scannedProductNames.add(product.name);
//         errorMessage = "";
//       }
//     } catch (e) {
//       errorMessage = "Error: $e";
//     }
//     isLoading = false;
//     _safeNotify();
//   }

//   Future<bool> saveProductsOnShelf() async {
//     if (scannedShelfId == null) return false;
//     isLoading = true;
//     _safeNotify();
//     final ok = await api.assignProductsToShelf(
//       scannedShelfId!,
//       scannedProductIds,
//     );
//     if (ok) {
//       scannedProductIds.clear();
//       scannedProductNames.clear();
//     }
//     isLoading = false;
//     _safeNotify();
//     return ok;
//   }

//   Future<void> findShelfForProduct(String ean) async {
//     isLoading = true;
//     _safeNotify();
//     final shelf = await api.findShelfByProduct(ean);
//     foundShelf = shelf;
//     if (shelf != null) {
//       productsOnShelf = await api.getProductsOnShelf(shelf.id);
//       errorMessage = "";
//     } else {
//       productsOnShelf = [];
//       errorMessage = "Not found";
//     }
//     isLoading = false;
//     _safeNotify();
//   }

//   void resetOrganize() {
//     scannedShelfId = null;
//     scannedShelfBarcode = '';
//     scannedProductIds.clear();
//     scannedProductNames.clear();
//     errorMessage = '';
//     _safeNotify();
//   }

//   void resetFind() {
//     foundShelf = null;
//     productsOnShelf = [];
//     errorMessage = '';
//     _safeNotify();
//   }
// }
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:flutter/material.dart';
import '../../services/warehouse_api_service.dart';
import '../../models/shelf.dart';
import '../../models/product.dart';

// Optional: For offline support, import Hive/sqflite here

enum WarehouseScanMode { createShelf, organize, find }

class WarehouseScannerController extends ChangeNotifier {
  final OfflineService _offlineService = OfflineService();

  final WarehouseApiService api;
  WarehouseScannerController({required this.api});

  // CREATE SHELF
  String shelfName = '';
  Shelf? createdShelf;

  // ORGANIZE
  String scannedShelfBarcode = '';
  int? scannedShelfId;
  List<int> scannedProductIds = [];
  List<String> scannedProductNames = [];
  String errorMessage = '';
  bool isLoading = false;

  // FIND
  Shelf? foundShelf;
  List<ShelfProduct> productsOnShelf = [];

  // 🛠️ Added safety flag
  bool _isDisposed = false;

  void _safeNotify() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void setShelfName(String name) {
    shelfName = name;
    _safeNotify();
  }

  Future<void> createShelf() async {
    isLoading = true;
    _safeNotify();

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      // First save shelf locally
      await _offlineService.saveShelfLabel(
        name: shelfName,
        barcode:
            'SHF-${DateTime.now().millisecondsSinceEpoch}', // Temporary barcode
      );

      // Log activity
      await _offlineService.logActivity(
        typeId: OfflineService.WAREHOUSE_SHELF,
        description: 'Kreirana polica lokalno: $shelfName',
        text: 'Shelf creation',
      );

      // If offline, use local data
      if (connectivityResult == ConnectivityResult.none) {
        errorMessage = '';
        createdShelf = Shelf(
          id: 0, // Temporary ID
          name: shelfName,
          barcode: 'SHF-${DateTime.now().millisecondsSinceEpoch}',
        );
        isLoading = false;
        _safeNotify();
        return;
      }

      // If online, create on server
      createdShelf = await api.createShelf(shelfName);

      if (createdShelf != null) {
        // Update the local record with server data
        await _offlineService.saveShelfLabel(
          name: createdShelf!.name,
          barcode: createdShelf!.barcode,
        );

        // Log creation success
        await _offlineService.logActivity(
          typeId: OfflineService.WAREHOUSE_SHELF,
          description: 'Kreirana polica: ${createdShelf!.name}',
          text: 'Shelf creation success',
        );
      }

      errorMessage = createdShelf == null ? "Error creating shelf." : "";
    } catch (e) {
      errorMessage = e.toString();
      // Log error
      await _offlineService.logActivity(
        typeId: OfflineService.WAREHOUSE_SHELF,
        description: 'Error creating shelf: $e',
        text: 'Shelf creation error',
      );
    }

    isLoading = false;
    _safeNotify();
  }

  Future<bool> scanShelfBarcode(String barcode) async {
    isLoading = true;
    _safeNotify();
    try {
      final shelf = await api.findShelfByProduct(barcode);
      if (shelf != null) {
        scannedShelfId = shelf.id;
        scannedShelfBarcode = shelf.barcode;
        errorMessage = '';
        scannedProductIds.clear();
        scannedProductNames.clear();
        isLoading = false;
        _safeNotify();
        return true;
      } else {
        errorMessage = "Shelf not found!";
        isLoading = false;
        _safeNotify();
        return false;
      }
    } catch (e) {
      errorMessage = e.toString();
      isLoading = false;
      _safeNotify();
      return false;
    }
  }

  Future<void> addProductByEAN(String ean) async {
    isLoading = true;
    _safeNotify();
    try {
      final product = await api.getProductByEAN(ean);
      if (product == null) {
        errorMessage = "Product not found!";
      } else if (scannedProductIds.contains(product.id)) {
        errorMessage = "Already added.";
      } else {
        scannedProductIds.add(product.id);
        scannedProductNames.add(product.name);
        errorMessage = "";
      }
    } catch (e) {
      errorMessage = "Error: $e";
    }
    isLoading = false;
    _safeNotify();
  }

  Future<bool> saveProductsOnShelf() async {
    if (scannedShelfId == null) return false;
    isLoading = true;
    _safeNotify();
    final ok = await api.assignProductsToShelf(
      scannedShelfId!,
      scannedProductIds,
    );
    if (ok) {
      scannedProductIds.clear();
      scannedProductNames.clear();
    }
    isLoading = false;
    _safeNotify();
    return ok;
  }

  Future<void> findShelfForProduct(String ean) async {
    isLoading = true;
    _safeNotify();
    final shelf = await api.findShelfByProduct(ean);
    foundShelf = shelf;
    if (shelf != null) {
      productsOnShelf = await api.getProductsOnShelf(shelf.id);
      errorMessage = "";
    } else {
      productsOnShelf = [];
      errorMessage = "Not found";
    }
    isLoading = false;
    _safeNotify();
  }

  void resetOrganize() {
    scannedShelfId = null;
    scannedShelfBarcode = '';
    scannedProductIds.clear();
    scannedProductNames.clear();
    errorMessage = '';
    _safeNotify();
  }

  void resetFind() {
    foundShelf = null;
    productsOnShelf = [];
    errorMessage = '';
    _safeNotify();
  }
}
