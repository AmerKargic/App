// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:digitalisapp/core/utils/logout_util.dart';
// import 'package:digitalisapp/core/utils/session_manager.dart';
// import 'package:digitalisapp/features/scanner/driver_order_scan_screen.dart';

// class DriverDashboard extends StatefulWidget {
//   const DriverDashboard({super.key});

//   @override
//   State<DriverDashboard> createState() => _DriverDashboardState();
// }

// class _DriverDashboardState extends State<DriverDashboard> {
//   String driverName = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadDriverName();
//   }

//   Future<void> _loadDriverName() async {
//     final session = SessionManager();
//     final userData = await session.getUser();
//     setState(() {
//       driverName = userData?['name'] ?? 'Vozač';
//     });
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
//                   _buildWelcomeHeader(),
//                   const Spacer(),
//                   _buildNeumorphicButton(
//                     icon: Icons.qr_code_scanner,
//                     label: 'Skeniraj paket',
//                     onTap: () => Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const DriverOrderScanScreen(),
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   _buildNeumorphicButton(
//                     icon: Icons.assignment,
//                     label: 'Kraj dana (uskoro)',
//                     onTap: () {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(
//                           content: Text('Opcija će uskoro biti dostupna.'),
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
//         icon: const Icon(Icons.logout),
//         color: Colors.grey.shade600,
//         onPressed: () => appLogout(),
//       ),
//     );
//   }

//   Widget _buildWelcomeHeader() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Dobrodošli,',
//           style: GoogleFonts.inter(
//             fontSize: 36,
//             fontWeight: FontWeight.w900,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.grey),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Colors.white70,
//               ),
//             ],
//           ),
//         ),
//         Text(
//           driverName,
//           style: GoogleFonts.inter(
//             fontSize: 28,
//             fontWeight: FontWeight.w700,
//             color: const Color(0xFFEDEDED),
//             shadows: const [
//               Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.grey),
//               Shadow(
//                 offset: Offset(-3, -1),
//                 blurRadius: 10,
//                 color: Colors.white70,
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

import 'package:digitalisapp/features/scanner/plates_scanner.dart';
import 'package:digitalisapp/models/offline_status_widget.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/scanner/driver_order_scan_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final OfflineService _offlineService = OfflineService();
  Timer? _syncTimer;
  bool _isSyncing = false;
  String driverName = '';

  @override
  void initState() {
    super.initState();
    _loadDriverName();

    // Start periodic sync
    _syncTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      if (!_isSyncing) {
        setState(() => _isSyncing = true);
        _offlineService.syncNow().then((_) {
          if (mounted) {
            setState(() => _isSyncing = false);
          }
        });
      }
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverName() async {
    final session = SessionManager();
    final userData = await session.getUser();
    setState(() {
      driverName = userData?['name'] ?? 'Vozač';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OfflineStatusWidget(),
                  const SizedBox(height: 75),
                  _buildWelcomeHeader(),
                  const Spacer(),
                  _buildNeumorphicButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Skeniraj paket',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DriverOrderScanScreen(),
                      ),
                    ),
                  ),
                  _buildNeumorphicButton(
                    icon: Icons.directions_car,
                    label: 'Skeniraj tablicu',
                    onTap: () async {
                      final plate = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LicensePlateScanner(),
                        ),
                      );
                      if (plate != null && plate.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Skenirana tablica: $plate')),
                        );
                        // Ovdje možeš odmah pozvati svoj API ili prikazati podatke
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),
                  _buildNeumorphicButton(
                    icon: Icons.assignment,
                    label: 'Kraj dana (uskoro)',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opcija će uskoro biti dostupna.'),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Positioned(top: 16, right: 16, child: _buildLogoutButton()),
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
        icon: const Icon(Icons.logout),
        color: Colors.grey.shade600,
        onPressed: () => appLogout(),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dobrodošli,',
          style: GoogleFonts.inter(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFEDEDED),
            shadows: const [
              Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.grey),
              Shadow(
                offset: Offset(-3, -1),
                blurRadius: 10,
                color: Colors.white70,
              ),
            ],
          ),
        ),
        Text(
          driverName,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFEDEDED),
            shadows: const [
              Shadow(offset: Offset(4, 4), blurRadius: 10, color: Colors.grey),
              Shadow(
                offset: Offset(-3, -1),
                blurRadius: 10,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNeumorphicButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFDEE1E6),
              offset: Offset(6, 6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.grey.shade700),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
                shadows: const [
                  Shadow(
                    offset: Offset(-1, -1),
                    color: Colors.white,
                    blurRadius: 0.5,
                  ),
                  Shadow(
                    offset: Offset(1, 1),
                    color: Colors.black12,
                    blurRadius: 0.5,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
