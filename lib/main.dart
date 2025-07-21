import 'package:digitalisapp/features/dashboard/screens/warehouse_dashboard.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart'; // <--- Add this!
import 'app_theme.dart';
import 'core/utils/session_manager.dart';
import 'features/auth/controllers/login_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/admin_dashboard.dart';
import 'features/dashboard/screens/skladistar_dashboard.dart';
import 'features/scanner/warehouse_scanner_screen.dart';
import 'services/warehouse_api_service.dart';

// Set your API base URL here:
const String warehouseApiBaseUrl = "https://yourserver.com/api/";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inject SessionManager as a dependency
  final session = SessionManager();
  Get.put<SessionManager>(session);

  final userData = await session.getUser();

  String initialRoute = '/';

  if (userData != null) {
    switch (userData['level']) {
      case 'admin':
        initialRoute = '/admin_dashboard';
        break;
      case 'kupac':
        initialRoute = '/skladistar_dashboard';
        break;
      case 'skladištar':
        initialRoute = '/warehouse';
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
        GetPage(name: '/', page: () => LoginScreen()),
        GetPage(
          name: '/admin_dashboard',
          page: () => AdminDashboard(adminName: ''),
        ),
        GetPage(
          name: '/skladistar_dashboard',
          page: () => WarehouseDashboard(),
        ),
        GetPage(name: '/warehouse', page: () => WarehouseDashboard()),
        // You can add more warehouse screens as needed:
        // For deep navigation:
        GetPage(
          name: '/warehouse_scanner',
          page: () =>
              WarehouseScannerScreen(mode: WarehouseScanMode.createShelf),
        ),
      ],
    );
  }
}
