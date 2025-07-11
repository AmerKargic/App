import 'package:get/get.dart';
import '../../services/api_service.dart';
import '../../core/utils/session_manager.dart';

class BarcodeScannerController extends GetxController {
  var isLoading = false.obs;
  var productInfo = {}.obs;
  var error = ''.obs;
  final changedIndexes = <int>{}.obs;

  final ApiService _apiService = ApiService();

  int kupId = 0;
  int level = 0;

  @override
  void onInit() {
    super.onInit();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = SessionManager();
    final user = await session.getUser();
    if (user != null) {
      kupId = user['kup_id'] ?? 0;
      level = user['level'] == 'admin' ? 99 : 0;
    }
  }

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

  Future<void> toggleLock(int index) async {
    if (level != 99) return;

    final list = List<Map>.from(productInfo['wishstock']);
    final item = list[index];
    final newLocked = item['stock_wish_locked'] == 1 ? 0 : 1;

    final res = await _apiService.saveLockState(
      aid: int.tryParse(productInfo['ID'].toString()) ?? 0,

      kupId: item['kup_id'],
      posId: item['pos_id'],
      locked: newLocked,
    );

    if (res['success'] == 1) {
      list[index]['stock_wish_locked'] = newLocked;
      productInfo['wishstock'] = list;
      Get.snackbar("Uspjeh", "Zaključavanje ažurirano.");
    } else {
      Get.snackbar("Greška", res['message'] ?? 'Neuspješno zaključavanje.');
    }
  }

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
        aid: int.tryParse(productInfo['ID'].toString()) ?? 0,

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
