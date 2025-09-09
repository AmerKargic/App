// import 'package:digitalisapp/core/utils/update_checker.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:digitalisapp/core/utils/logout_util.dart';
// import 'package:digitalisapp/core/utils/session_manager.dart';
// import 'package:digitalisapp/features/scanner/barcode_scanner_screen.dart';

// class AdminDashboard extends StatefulWidget {
//   const AdminDashboard({Key? key, required String adminName}) : super(key: key);

//   @override
//   State<AdminDashboard> createState() => _AdminDashboardState();
// }

// class _AdminDashboardState extends State<AdminDashboard> {
//   String? adminName;
//   bool firstLogin = false;

//   @override
//   void initState() {
//     UpdateChecker.checkForUpdate(context);
//     super.initState();
//     _loadAdminName();
//   }

//   Future<void> _loadAdminName() async {
//     final session = SessionManager();
//     final userData = await session.getUser();
//     setState(() {
//       adminName = userData?['name'] ?? '';
//       firstLogin = userData?['firstLogin'] ?? false;
//     });
//     if (firstLogin) {
//       userData?['firstLogin'] = false;
//       await session.saveUser(userData!);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F4F6),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 30),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 75),

//                   Row(
//                     crossAxisAlignment:
//                         CrossAxisAlignment.start, // ← top-aligns children
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Expanded(
//                         child: _buildWelcomeHeader(),
//                       ), // allows welcome text to wrap
//                     ],
//                   ),
//                   const Spacer(),
//                   _buildNeumorphicButton(
//                     icon: Icons.bar_chart,
//                     label: 'Admin dashboard',
//                     onTap: () {},
//                   ),
//                   const SizedBox(height: 20),
//                   _buildNeumorphicButton(
//                     icon: Icons.qr_code_scanner,
//                     label: 'Barcode scanner',
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => BarcodeScannerScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                   const Spacer(),
//                 ],
//               ),
//             ),
//             Positioned(top: 16, right: 16, child: _buildLogoutButton()),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLogoutButton() {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFFF3F4F6),
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: const [
//           BoxShadow(
//             offset: Offset(4, 4),
//             blurRadius: 8,
//             color: Color(0xFFD1D9E6),
//           ),
//           BoxShadow(offset: Offset(-4, -4), blurRadius: 8, color: Colors.white),
//         ],
//       ),
//       child: IconButton(
//         icon: const Icon(Icons.arrow_forward),
//         color: Colors.grey.shade600,
//         onPressed: () => appLogout(),
//       ),
//     );
//   }

//   Widget _buildWelcomeHeader() {
//     const darkShadow = Color.fromARGB(255, 151, 155, 161);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           firstLogin ? 'Welcome,' : 'Welcome back,',
//           style: GoogleFonts.inter(
//             fontSize: 40,
//             fontWeight: FontWeight.w900,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Color.fromARGB(150, 255, 255, 255),
//               ),
//             ],
//           ),
//         ),

//         Text(
//           adminName ?? '',
//           style: GoogleFonts.inter(
//             fontSize: 32,
//             fontWeight: FontWeight.w900,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Color.fromARGB(150, 255, 255, 255),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildNeumorphicButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         decoration: BoxDecoration(
//           color: const Color(0xFFF3F4F6), // match background
//           borderRadius: BorderRadius.circular(22), // softer corners
//           boxShadow: const [
//             BoxShadow(
//               color: Color(0xFFDEE1E6), // soft bottom shadow
//               offset: Offset(6, 6),
//               blurRadius: 12,
//               spreadRadius: 1,
//             ),
//             BoxShadow(
//               color: Colors.white, // top-left highlight
//               offset: Offset(-6, -6),
//               blurRadius: 12,
//               spreadRadius: 1,
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(icon, size: 22, color: Colors.grey.shade700),
//             const SizedBox(width: 14),
//             Text(
//               label,
//               style: GoogleFonts.inter(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//                 shadows: const [
//                   Shadow(
//                     offset: Offset(-1, -1),
//                     color: Colors.white,
//                     blurRadius: 0.5,
//                   ),
//                   Shadow(
//                     offset: Offset(1, 1),
//                     color: Colors.black12,
//                     blurRadius: 0.5,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

/////// DRUGI POKUSAJ
// import 'dart:convert';

// import 'package:digitalisapp/core/utils/update_checker.dart';
// import 'package:digitalisapp/features/maps/drivers_map_screen.dart';
// import 'package:digitalisapp/models/driver_order_model.dart';
// import 'package:digitalisapp/models/driver_orders_sheet.dart';
// import 'package:digitalisapp/services/admin_api_service.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:digitalisapp/core/utils/logout_util.dart';
// import 'package:digitalisapp/core/utils/session_manager.dart';
// import 'package:digitalisapp/features/scanner/barcode_scanner_screen.dart';
// import 'package:http/http.dart' as http;
//allahuekber

// class AdminDashboard extends StatefulWidget {
//   const AdminDashboard({Key? key, required String adminName}) : super(key: key);

//   @override
//   State<AdminDashboard> createState() => _AdminDashboardState();
// }

// class _AdminDashboardState extends State<AdminDashboard> {
//   String? adminName;
//   bool firstLogin = false;
//   final AdminApiService _adminApiService = AdminApiService();
//   List<Map<String, dynamic>> _drivers = [];

//   @override
//   void initState() {
//     UpdateChecker.checkForUpdate(context);
//     super.initState();
//     _loadAdminName();
//     _fetchAdminDashboardData();
//   }

//   /// Fetch combined admin dashboard data
//   Future<void> _fetchAdminDashboardData() async {
//     try {
//       final drivers = await _adminApiService.fetchAdminDashboardData();
//       setState(() {
//         _drivers = drivers;
//       });
//     } catch (e) {
//       print('Error fetching admin dashboard data: $e');
//     }
//   }

//   Future<void> _loadAdminName() async {
//     final session = SessionManager();
//     final userData = await session.getUser();
//     setState(() {
//       adminName = userData?['name'] ?? '';
//       firstLogin = userData?['firstLogin'] ?? false;
//     });
//     if (firstLogin) {
//       userData?['firstLogin'] = false;
//       await session.saveUser(userData!);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF3F4F6),
//       body: SafeArea(
//         child: Stack(
//           children: [
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 30),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const SizedBox(height: 75),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [Expanded(child: _buildWelcomeHeader())],
//                   ),
//                   const Spacer(),
//                   _buildNeumorphicButton(
//                     icon: Icons.map,
//                     label: 'View Drivers Map',
//                     onTap: () {
//                       // Navigate to the map screen with the updated drivers list
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) =>
//                               DriversMapScreen(drivers: _drivers),
//                         ),
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 20),
//                   _buildNeumorphicButton(
//                     icon: Icons.qr_code_scanner,
//                     label: 'Barcode scanner',
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => BarcodeScannerScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                   const Spacer(),
//                 ],
//               ),
//             ),
//             Positioned(top: 16, right: 16, child: _buildLogoutButton()),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLogoutButton() {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFFF3F4F6),
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: const [
//           BoxShadow(
//             offset: Offset(4, 4),
//             blurRadius: 8,
//             color: Color(0xFFD1D9E6),
//           ),
//           BoxShadow(offset: Offset(-4, -4), blurRadius: 8, color: Colors.white),
//         ],
//       ),
//       child: IconButton(
//         icon: const Icon(Icons.arrow_forward),
//         color: Colors.grey.shade600,
//         onPressed: () => appLogout(),
//       ),
//     );
//   }

//   Widget _buildWelcomeHeader() {
//     const darkShadow = Color.fromARGB(255, 151, 155, 161);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           firstLogin ? 'Welcome,' : 'Welcome back,',
//           style: GoogleFonts.inter(
//             fontSize: 40,
//             fontWeight: FontWeight.w900,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Color.fromARGB(150, 255, 255, 255),
//               ),
//             ],
//           ),
//         ),
//         Text(
//           adminName ?? '',
//           style: GoogleFonts.inter(
//             fontSize: 32,
//             fontWeight: FontWeight.w900,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Color.fromARGB(150, 255, 255, 255),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildNeumorphicButton({
//     required IconData icon,
//     required String label,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
//         margin: const EdgeInsets.symmetric(vertical: 6),
//         decoration: BoxDecoration(
//           color: const Color(0xFFF3F4F6),
//           borderRadius: BorderRadius.circular(22),
//           boxShadow: const [
//             BoxShadow(
//               color: Color(0xFFDEE1E6),
//               offset: Offset(6, 6),
//               blurRadius: 12,
//               spreadRadius: 1,
//             ),
//             BoxShadow(
//               color: Colors.white,
//               offset: Offset(-6, -6),
//               blurRadius: 12,
//               spreadRadius: 1,
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             Icon(icon, size: 22, color: Colors.grey.shade700),
//             const SizedBox(width: 14),
//             Text(
//               label,
//               style: GoogleFonts.inter(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.grey.shade700,
//                 shadows: const [
//                   Shadow(
//                     offset: Offset(-1, -1),
//                     color: Colors.white,
//                     blurRadius: 0.5,
//                   ),
//                   Shadow(
//                     offset: Offset(1, 1),
//                     color: Colors.black12,
//                     blurRadius: 0.5,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'package:digitalisapp/core/utils/update_checker.dart';

import 'package:digitalisapp/features/dashboard/screens/analytics_dashboard.dart';
import 'package:digitalisapp/features/maps/drivers_map_screen.dart';
import 'package:digitalisapp/services/admin_api_service.dart';
import 'package:digitalisapp/services/analytics_api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/scanner/barcode_scanner_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key, required String adminName}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  String? adminName;
  bool firstLogin = false;
  final AdminApiService _adminApiService = AdminApiService();
  final AnalyticsApiService _analyticsService = AnalyticsApiService();
  List<Map<String, dynamic>> _drivers = [];

  // Real-time analytics data
  Map<String, dynamic> _realtimeStats = {};
  Timer? _analyticsTimer;
  late AnimationController _pulseController;
  late AnimationController _rotateController;

  @override
  void initState() {
    UpdateChecker.checkForUpdate(context);
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();

    _loadAdminName();
    _fetchAdminDashboardData();
    _startRealtimeAnalytics();
  }

  @override
  void dispose() {
    _analyticsTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  /// Start real-time analytics updates
  void _startRealtimeAnalytics() {
    _analyticsTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _fetchRealtimeStats();
    });
    _fetchRealtimeStats(); // Initial fetch
  }

  /// Fetch real-time statistics
  Future<void> _fetchRealtimeStats() async {
    try {
      final stats = await _analyticsService.getRealtimeStats();
      if (mounted) {
        setState(() {
          _realtimeStats = stats;
        });
      }
    } catch (e) {
      print('Error fetching real-time stats: $e');
    }
  }

  /// Fetch combined admin dashboard data
  Future<void> _fetchAdminDashboardData() async {
    try {
      final drivers = await _adminApiService.fetchAdminDashboardData();
      setState(() {
        _drivers = drivers;
      });
    } catch (e) {
      print('Error fetching admin dashboard data: $e');
    }
  }

  Future<void> _loadAdminName() async {
    final session = SessionManager();
    final userData = await session.getUser();
    setState(() {
      adminName = userData?['name'] ?? '';
      firstLogin = userData?['firstLogin'] ?? false;
    });
    if (firstLogin) {
      userData?['firstLogin'] = false;
      await session.saveUser(userData!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 45),

                  // Welcome header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Expanded(child: _buildWelcomeHeader())],
                  ),

                  const SizedBox(height: 30),

                  // Real-time stats cards
                  _buildRealtimeStatsCards(),

                  const SizedBox(height: 30),

                  // Main action buttons
                  _buildActionButtons(),

                  const SizedBox(height: 20),
                ],
              ),
            ),

            // Floating logout button
            Positioned(top: 16, right: 16, child: _buildLogoutButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeStatsCards() {
    final activeDrivers = _realtimeStats['active_drivers'] ?? 0;
    final totalDeliveries = _realtimeStats['total_deliveries_today'] ?? 0;
    final avgDeliveryTime = _realtimeStats['avg_delivery_time'] ?? 0.0;
    final onTimeRate = _realtimeStats['on_time_percentage'] ?? 0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Aktivni vozači',
                value: activeDrivers.toString(),
                icon: Icons.local_shipping,
                color: Colors.blue,
                animation: _pulseController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Dostave danas',
                value: totalDeliveries.toString(),
                icon: Icons.assignment_turned_in,
                color: Colors.green,
                animation: _rotateController,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                title: 'Prosečno vreme',
                value: '${avgDeliveryTime.toStringAsFixed(1)} min',
                icon: Icons.access_time,
                color: Colors.orange,
                animation: _pulseController,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                title: 'Na vreme',
                value: '${onTimeRate.toStringAsFixed(1)}%',
                icon: Icons.trending_up,
                color: onTimeRate >= 90
                    ? Colors.green
                    : onTimeRate >= 75
                    ? Colors.orange
                    : Colors.red,
                animation: _rotateController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required AnimationController animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                offset: Offset(0, 8),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.white,
                offset: Offset(-8, -8),
                blurRadius: 15,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(animation.value),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildNeumorphicButton(
          icon: Icons.analytics,
          label: 'Napredna Analitika',
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.blue.shade500],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriverAnalyticsDashboard(),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildNeumorphicButton(
          icon: Icons.map,
          label: 'Mapa vozača',
          gradient: LinearGradient(
            colors: [Colors.green.shade400, Colors.teal.shade500],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DriversMapScreen(drivers: _drivers),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        _buildNeumorphicButton(
          icon: Icons.qr_code_scanner,
          label: 'Barcode scanner',
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.red.shade500],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BarcodeScannerScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNeumorphicButton({
    required IconData icon,
    required String label,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              offset: Offset(6, 6),
              blurRadius: 20,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              offset: Offset(-6, -6),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.8),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            offset: Offset(4, 4),
            blurRadius: 8,
            color: Color(0xFFD1D9E6),
          ),
          BoxShadow(offset: Offset(-4, -4), blurRadius: 8, color: Colors.white),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_forward),
        color: Colors.grey.shade600,
        onPressed: () => appLogout(),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    const darkShadow = Color.fromARGB(255, 151, 155, 161);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstLogin ? 'Welcome,' : 'Welcome back,',
          style: GoogleFonts.inter(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEDEDED),
            shadows: const [
              Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
              Shadow(
                offset: Offset(-3, -1),
                blurRadius: 10,
                color: Color.fromARGB(150, 255, 255, 255),
              ),
            ],
          ),
        ),
        Text(
          adminName ?? '',
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEDEDED),
            shadows: const [
              Shadow(offset: Offset(4, 4), blurRadius: 10, color: darkShadow),
              Shadow(
                offset: Offset(-3, -1),
                blurRadius: 10,
                color: Color.fromARGB(150, 255, 255, 255),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
