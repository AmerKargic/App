import 'package:get/get.dart';
import 'session_manager.dart';

Future<void> appLogout() async {
  final session = Get.find<SessionManager>();
  await session.clearUser();
  Get.offAllNamed('/'); // Vrati na login screen
}
