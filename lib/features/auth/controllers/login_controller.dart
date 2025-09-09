import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/dashboard/screens/driver_dashboard.dart';
import 'package:digitalisapp/features/dashboard/screens/skladistar_dashboard.dart';
import 'package:digitalisapp/features/dashboard/screens/warehouse_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../models/user_model.dart';
import 'package:digitalisapp/features/dashboard/screens/admin_dashboard.dart';

// login screen koji nam sluzi samo za podjelu rola i provjeru sesije :D
class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var isLoading = false.obs;

  void login() async {
    isLoading.value = true;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final apiService = ApiService();
    final response = await apiService.login(email, password);

    isLoading.value = false;

    if (response['success'] == true || response['success'] == 1) {
      final user = UserModel.fromJson(response['data']);

      final session = SessionManager();
      await session.saveUser({
        'kup_id': user.kupId,
        'pos_id': user.posId,
        'name': user.name,
        'email': user.email,
        'level': user.level,
        'hash1': user.hash1,
        'hash2': user.hash2,
        'firstLogin': true,
      });
      final loaded = await session.getUser();
      //sve printove odavde mozemo ukloniti kad zavrsimo sa debuggingom
      print('Loaded user after save: $loaded');
      print('LOGIN RESPONSE: ${response['data']}');
      print('USER OBJ: ${user.toJson()}');
      switch (user.level) {
        case 'skladištar':
          Get.offAll(() => SkladistarDashboard(skladistarName: user.name));
          print('Prebacivanje na skladistar screen'); // DEBUG
          break;
        case 'admin':
          Get.offAll(() => AdminDashboard(adminName: user.name));
          // ignore: avoid_print
          print('prebaceno na admin screen');
          break;
        case 'vozac':
          Get.offAll(() => DriverDashboard());
          print('Prebaceno na vozac screen'); // DEBUG

          break;
        case 'kupac':
          Get.offAll(() => WarehouseDashboard());
          print(
            'prebaceno na screen za skladistara jer je on kao kupac naveden u bazi',
          );

          break;
        case 'vozač':
          Get.offAll(() => DriverDashboard());
          print(
            'Prebaceno opet na vozac screen jer imamo negdje vozac negdje sa č',
          );
          break;
        default:
          Get.snackbar('Greška', 'Nepoznata korisnička rola');
          print('ne postoji role');
      }
    } else {
      Get.snackbar(
        'Login neuspješan',

        response['message'] ?? 'Greška prilikom prijave',
      );
    }
  }
}
