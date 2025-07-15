import 'package:digitalisapp/features/scanner/barcode_scanner_controller.dart';
import 'package:get/get.dart';
import 'session_manager.dart';

Future<void> appLogout() async {
  final session = Get.find<SessionManager>();
  await session.clearUser();
  Get.delete<BarcodeScannerController>();
  Get.offAllNamed('/'); // Vrati na login screen
}
