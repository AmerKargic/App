import 'package:get/get.dart';
import '../../services/api_service.dart';

class BarcodeScannerController extends GetxController {
  var isLoading = false.obs;
  var productInfo = {}.obs;
  var error = ''.obs;

  final ApiService _apiService = ApiService();

  // Should be injected at login time
  int kupId = 0; // Your user ID
  int level = 0; // Admin if level == 99, for example

  Future<void> fetchProduct(String barcode) async {
    isLoading.value = true;
    error.value = '';
    productInfo.value = {};

    try {
      final response = await _apiService.getProductByBarcode(barcode);
      if (response['success'] == 1 && response['data'] != null) {
        productInfo.value = response['data'];
      } else {
        error.value = response['message'] ?? 'Proizvod nije pronađen.';
      }
    } catch (e) {
      error.value = 'Greška: $e';
    } finally {
      isLoading.value = false;
    }
  }

  bool canEditWishstock(Map item) {
    if (level == 99) return true; // admin
    return item['kup_id'] == kupId && item['stock_wish_locked'] == 0;
  }

  void toggleLock(int index) {
    if (level != 99) return;
    final list = List<Map>.from(productInfo['wishstock']);
    list[index]['stock_wish_locked'] = list[index]['stock_wish_locked'] == 1
        ? 0
        : 1;
    productInfo['wishstock'] = list;
  }

  final changedIndexes = <int>{}.obs;

  void updateWishstock(int index, double newVal) {
    final list = List<Map>.from(productInfo['wishstock']);
    if (list[index]['stock_wish'] != newVal) {
      list[index]['stock_wish'] = newVal;
      changedIndexes.add(index);
      productInfo['wishstock'] = list;
    }
  }

  Future<void> saveWishstockChanges() async {
    final list = List<Map>.from(productInfo['wishstock']);
    isLoading.value = true;

    for (final index in changedIndexes) {
      final item = list[index];
      await _apiService.saveWishstock(
        aid: productInfo['ID'],
        kupId: item['kup_id'],
        posId: item['pos_id'],
        stockWish: item['stock_wish'],
      );
    }

    changedIndexes.clear();
    isLoading.value = false;
    Get.snackbar("Uspjeh", "Izmjene sačuvane.");
  }
}
