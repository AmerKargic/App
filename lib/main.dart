// import 'dart:async';
import 'dart:async';
import 'dart:convert';

import 'package:digitalisapp/features/dashboard/screens/driver_dashboard.dart';
import 'package:digitalisapp/features/dashboard/screens/warehouse_dashboard.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/controllers/login_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/admin_dashboard.dart';
import 'features/dashboard/screens/skladistar_dashboard.dart';
import 'features/scanner/warehouse_scanner_screen.dart';
import 'services/warehouse_api_service.dart';
import 'services/offline_services.dart'; // Add this import

// 🔥 GLOBALNI EVENT STREAM
class ForceLogoutEvent {}

final StreamController<ForceLogoutEvent> _forceLogoutController =
    StreamController<ForceLogoutEvent>.broadcast();

Stream<ForceLogoutEvent> get forceLogoutStream => _forceLogoutController.stream;

void triggerForceLogout() {
  _forceLogoutController.add(ForceLogoutEvent());
}

// Set your API base URL here:
const String warehouseApiBaseUrl =
    //"https://www.digitalis.ba/webshop/appinternal/api/";
    "http://10.0.2.2/webshop/appinternal/api/";
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a single instance of OfflineService
  final offlineService = OfflineService();
  await offlineService.database;
  offlineService.deactivateRoute();

  // Start location tracking
  offlineService.startLocationTracking();

  // Set up periodic cleanup
  Timer.periodic(const Duration(days: 1), (_) {
    offlineService.cleanupOldData();
  });
  // Inject SessionManager as a dependency
  final session = SessionManager();
  Get.put<SessionManager>(session);

  // Initialize offline service
  try {
    final offlineService = OfflineService();
    await offlineService.database;

    // Set up periodic cleanup
    Timer.periodic(const Duration(days: 1), (_) {
      offlineService.cleanupOldData();
    });

    // Try initial sync if there's a logged in user
    final user = await session.getUser();
    if (user != null) {
      offlineService.syncNow();
    }
  } catch (e) {
    debugPrint("Error initializing offline database: $e");
  }

  final userData = await SessionManager().getUser();

  String initialRoute = '/';

  if (userData != null) {
    switch (userData['level']) {
      case 'admin':
        initialRoute = '/admin_dashboard';
        break;
      case 'skladištar':
        initialRoute = '/skladistar_dashboard';
        break;
      case 'kupac':
        initialRoute = '/warehouse_dashboard';
        break;

      case 'vozac':
        initialRoute = '/driver_dashboard';
        break;
      default:
        initialRoute = '/';
    }
  }

  Get.put(LoginController());

  runApp(
    MultiProvider(
      providers: [
        Provider<WarehouseApiService>(create: (_) => WarehouseApiService()),
        // You can add more providers here if needed
      ],
      child: MyApp(initialRoute: initialRoute, LoginScreen: false),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({Key? key, required this.initialRoute, required bool LoginScreen})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Digitalis',
      theme: customLightTheme,
      darkTheme: customDarkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      getPages: [
        GetPage(name: '/', page: () => const LoginScreen()),
        GetPage(
          name: '/admin_dashboard',
          page: () => const AdminDashboard(adminName: ''),
        ),
        GetPage(
          name: '/skladistar_dashboard',
          page: () => const SkladistarDashboard(skladistarName: ''),
        ),
        GetPage(name: '/driver_dashboard', page: () => const DriverDashboard()),
        GetPage(
          name: '/warehouse_dashboard',
          page: () => const WarehouseDashboard(),
        ),
        // You can add more warehouse screens as needed:
        // For deep navigation:
        GetPage(
          name: '/warehouse_scanner',
          page: () =>
              const WarehouseScannerScreen(mode: WarehouseScanMode.createShelf),
        ),
      ],
    );
  }
}
