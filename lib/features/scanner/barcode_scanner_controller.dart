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
  int posId = 0;
  final level = ''.obs;

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
      posId = user['pos_id'] ?? 0; // make sure your session has this
      level.value = user['level'] ?? '';
    }

    debugPrintSession();
  }

  void debugPrintSession() {
    print('DEBUG: BarcodeScannerController session/user:');
    print('level: ${level.value}');
    // Add more if you store other info, like:
    // print('name: $name');
    // print('email: $email');
  }

  bool isOwnStore(Map item) {
    return item['kup_id'].toString() == kupId.toString() &&
        item['pos_id'].toString() == posId.toString();
  }

  Future<void> fetchProduct(String barcode) async {
    isLoading.value = true;
    error.value = '';
    productInfo.value = {};

    try {
      final response = await _apiService.getProductByBarcode(
        barcode,
        kupId,
        posId,
      );
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
    if (level.value == 'admin') return true;
    final isMine =
        item['kup_id'].toString() == kupId.toString() &&
        item['pos_id'].toString() == posId.toString();
    final locked = item['stock_wish_locked'].toString() == '1';
    return isMine && !locked;
  }

  Future<void> toggleLock(int index) async {
    if (level.value != 'admin') {
      // Optionally show a warning:
      Get.snackbar(
        "Zabranjeno",
        "Samo admin može zaključavati ili otključavati.",
      );
      return;
    }

    final list = List<Map>.from(productInfo['wishstock']);
    final item = list[index];
    final newLocked = item['stock_wish_locked'].toString() == '1' ? 0 : 1;

    final res = await _apiService.saveLockState(
      aid: int.tryParse(productInfo['ID'].toString()) ?? 0,
      kupId: int.tryParse(item['kup_id'].toString()) ?? 0,
      posId: int.tryParse(item['pos_id'].toString()) ?? 0,
      locked: newLocked,
    );

    if (res['success'] == 1) {
      list[index]['stock_wish_locked'] = newLocked;
      productInfo['wishstock'] = list;

      Get.snackbar("Uspjeh", "Zaključavanje ažurirano.");
      productInfo.refresh();
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

      if (!canEditWishstock(item)) continue; // prevent unintended updates

      await _apiService.saveWishstock(
        aid: int.tryParse(productInfo['ID'].toString()) ?? 0,
        kupId: int.tryParse(item['kup_id'].toString()) ?? 0,
        posId: int.tryParse(item['pos_id'].toString()) ?? 0,
        stockWish: double.tryParse(item['stock_wish'].toString()) ?? 0,
      );
    }

    changedIndexes.clear();
    isLoading.value = false;
    Get.snackbar("Uspjeh", "Izmjene sačuvane.");
  }
}
