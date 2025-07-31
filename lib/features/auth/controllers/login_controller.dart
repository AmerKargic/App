import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/dashboard/screens/driver_dashboard.dart';
import 'package:digitalisapp/features/dashboard/screens/skladistar_dashboard.dart';
import 'package:digitalisapp/features/dashboard/screens/warehouse_dashboard.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/api_service.dart';
import '../../../models/user_model.dart';
import 'package:digitalisapp/features/dashboard/screens/admin_dashboard.dart';

class LoginController extends GetxController {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  var isLoading = false.obs;

  // Your existing navigation code
  // ...
  void login() async {
    isLoading.value = true;

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    final apiService = ApiService();
    final response = await apiService.login(email, password);

    isLoading.value = false;
    // checking roles and assigning screens (modules)

    if (response['success'] == true || response['success'] == 1) {
      final user = UserModel.fromJson(response['data']);

      //Seng user data to session manager
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
      print('Loaded user after save: $loaded');
      print('LOGIN RESPONSE: ${response['data']}');
      print('USER OBJ: ${user.toJson()}');
      //checking user level and navigating to the appropriate dashboard
      switch (user.level) {
        case 'skladištar':
          Get.offAll(() => SkladistarDashboard(skladistarName: user.name));

          break;
        case 'admin':
          Get.offAll(() => AdminDashboard(adminName: user.name));
          // ignore: avoid_print

          break;
        case 'vozac':
          Get.offAll(() => DriverDashboard());
          break;
        case 'kupac':
          Get.offAll(() => WarehouseDashboard());
          break;
        case 'vozač':
          Get.offAll(() => DriverDashboard());
          break;
        default:
          Get.snackbar('Greška', 'Nepoznata korisnička rola');
      }
    } else {
      Get.snackbar(
        'Login neuspješan',
        response['message'] ?? 'Greška prilikom prijave',
      );
    }
  }

  void _onLoginSuccess(Map<String, dynamic> userData) async {
    // Initialize offline service for this user
    final offlineService = OfflineService();
    try {
      await offlineService.database;
      // Try to sync any pending data
      offlineService.syncNow();
    } catch (e) {
      debugPrint('Error initializing offline database: $e');
    }
  }
}
