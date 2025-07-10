import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/utils/session_manager.dart';
import 'features/auth/controllers/login_controller.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/admin_dashboard.dart';
// import 'features/dashboard/screens/skladistar_dashboard.dart';
// import 'features/dashboard/screens/retail_dashboard.dart';

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
      case 'komercijalist':
        initialRoute = '/retail';
        break;
      case 'skladištar':
        initialRoute = '/warehouse';
        break;
      default:
        initialRoute = '/';
    }
  }

  Get.put(LoginController());

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Digitalis',
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      getPages: [
        GetPage(name: '/', page: () => LoginScreen()),
        GetPage(
          name: '/admin_dashboard',
          page: () => AdminDashboard(adminName: ''),
        ),
        // Add your other routes here, for example:
        // GetPage(name: '/warehouse', page: () => SkladistarDashboard(user: ...)),
        // GetPage(name: '/retail', page: () => RetailDashboard()),
      ],
    );
  }
}
