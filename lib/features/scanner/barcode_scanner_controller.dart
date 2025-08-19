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
  List<String> allowedMagacini = [];
  String hash1 = '';
  String hash2 = '';
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
      // make sure your session has this
      level.value = user['level'] ?? '';
      hash1 = user['hash1'] ?? '';
      hash2 = user['hash2'] ?? '';
      await _loadAllowedMagacini();
    }

    debugPrintSession();
  }

  Future<void> _loadAllowedMagacini() async {
    print('🔍 _loadAllowedMagacini called');
    try {
      final response = await ApiService.getUserPermissions();
      print('🔍 getUserPermissions response: $response');

      if (response['success'] == 1 && response['data']?['options'] != null) {
        final options = response['data']['options'];
        print('🔍 options: $options');

        if (options['PristupProknjizi'] == 1 ||
            options['pravo_pregleda_svihmpkomercs'] == 1) {
          allowedMagacini = [];
          print('🔑 Full access to all magacini');
        } else {
          final magaciniArray =
              options['Magacini_ID_array'] as Map<String, dynamic>?;
          if (magaciniArray != null) {
            allowedMagacini = magaciniArray.keys.toList();
            print('🔒 Restricted to magacini: $allowedMagacini');
          } else {
            allowedMagacini = ['333', '334'];
            print('🔒 Fallback magacini: $allowedMagacini');
          }
        }
      } else {
        print('❌ Failed to get permissions, using fallback');
        allowedMagacini = ['333', '334'];
      }
    } catch (e) {
      print('❌ Error loading magacini permissions: $e');
      allowedMagacini = ['333', '334'];
    }

    print('🔍 Final allowedMagacini: $allowedMagacini');
  }

  void debugPrintSession() {
    print('DEBUG: BarcodeScannerController session/user:');
    print('level: ${level.value}');
    // Add more if you store other info, like:
    // print('name: $name');
    // print('email: $email');
  }

  bool isOwnStore(Map item) {
    final itemMagacinId = item['mag_id']?.toString();
    final itemKupId = item['kup_id']?.toString();

    print('🔍 isOwnStore check:');
    print('  - itemKupId: $itemKupId vs myKupId: $kupId');
    print('  - itemMagId: $itemMagacinId');
    print('  - allowedMagacini: $allowedMagacini');

    // Ako je allowedMagacini prazna lista = full access
    if (allowedMagacini.isEmpty) {
      print('  - Full access mode: true');
      return true;
    }

    // 🔥 NOVA LOGIKA: PROVJERI SAMO MAGACIN, NE kup_id!
    // Skladištar može mijenjati SVE u svojem magacinu, bez obzira na kup_id
    final result =
        itemMagacinId != null && allowedMagacini.contains(itemMagacinId);
    print(
      '  - Magacin-only mode: $result (mag_id $itemMagacinId in $allowedMagacini)',
    );
    return result;
  }

  Future<void> fetchProduct(String barcode) async {
    isLoading.value = true;
    error.value = '';
    productInfo.value = {};

    try {
      final response = await _apiService.getProductByBarcode(
        barcode,
        kupId,
        0, // pos_id se ne koristi više
        hash1,
        hash2,
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
    print('🔍 canEditWishstock called for item: $item');
    print('🔍 user level: ${level.value}');
    print('🔍 allowedMagacini: $allowedMagacini');

    if (level.value == 'admin') {
      print('✅ Admin access granted');
      return true;
    }

    final isMine = isOwnStore(item);
    final locked = item['stock_wish_locked'].toString() == '1';
    final itemMagacinId = item['mag_id']?.toString(); // ✅ PROMIJENI OVO!

    print('🔍 itemMag_id: $itemMagacinId'); // ✅ PROMIJENI DEBUG
    print('🔍 isMine: $isMine');
    print('🔍 locked: $locked');

    final canEdit = isMine && !locked;
    print(canEdit ? '✅ Can edit' : '❌ Cannot edit');

    return canEdit;
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

  void updateWishstock(String magacinId, double newVal) {
    final list = List<Map>.from(productInfo['wishstock']);
    final realIndex = list.indexWhere(
      (p) => p['mag_id']?.toString() == magacinId,
    );

    print(
      'DEBUG [updateWishstockByMagId] magacinId=$magacinId, newVal=$newVal, realIndex=$realIndex',
    );

    if (realIndex != -1 && list[realIndex]['stock_wish'] != newVal) {
      print(
        'DEBUG [updateWishstockByMagId] Changing stock_wish from ${list[realIndex]['stock_wish']} to $newVal',
      );
      list[realIndex]['stock_wish'] = newVal;
      changedIndexes.add(realIndex);
      productInfo['wishstock'] = list;
    }
  }

  Future<void> fetchProductByAID(String aid) async {
    isLoading.value = true;
    error.value = '';
    productInfo.value = {};

    try {
      final response = await _apiService.getProductByAID(
        aid,
        kupId,
        hash1,
        hash2,
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

  Future<void> saveWishstockChanges() async {
    final list = List<Map>.from(productInfo['wishstock']);
    isLoading.value = true;

    for (final index in changedIndexes) {
      final item = list[index];

      if (!canEditWishstock(item)) continue;

      // 🔥 KORISTI mag_id UMJESTO magacin_id!
      final magacinId = item['mag_id']?.toString(); // ✅ PROMIJENI OVO!
      if (magacinId == null) {
        print('⚠️ Missing mag_id for item at index $index');
        continue;
      }

      print(
        '🔍 Saving wishstock: aid=${productInfo['ID']}, mag_id=$magacinId, stock=${item['stock_wish']}',
      );

      await ApiService.saveWishstockNew(
        aid: int.tryParse(productInfo['ID'].toString()) ?? 0,
        stockWish: double.tryParse(item['stock_wish'].toString()) ?? 0,
        magacinId: magacinId,
      );
    }

    changedIndexes.clear();
    isLoading.value = false;
    Get.snackbar("Uspjeh", "Izmjene sačuvane.");
  }
}
