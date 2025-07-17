import 'package:digitalisapp/core/utils/update_checker.dart';
import 'package:digitalisapp/features/products/screens/product_screen.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/scanner/barcode_scanner_screen.dart';

class SkladistarDashboard extends StatefulWidget {
  const SkladistarDashboard({Key? key, required String skladistarName})
    : super(key: key);

  @override
  State<SkladistarDashboard> createState() => _SkladistarDashboardState();
}

class _SkladistarDashboardState extends State<SkladistarDashboard> {
  String? userName;
  bool firstLogin = false;

  @override
  void initState() {
    UpdateChecker.checkForUpdate(context);
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final session = SessionManager();
    final userData = await session.getUser();
    setState(() {
      userName = userData?['name'] ?? '';
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 75),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Expanded(child: _buildWelcomeHeader())],
                  ),
                  const Spacer(),
                  _buildNeumorphicButton(
                    icon: Icons.inventory,
                    label: 'Warehouse',
                    onTap: () {
                      //navigate to product_screen.dart
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductsListScreen(
                            kupId: 0, // Replace with actual kupId
                            posId: 0, // Replace with actual posId
                            apiService: ApiService(),
                          ),
                        ),
                      );
                    }, // You can implement your Skladistar-specific action here
                  ),
                  const SizedBox(height: 20),
                  _buildNeumorphicButton(
                    icon: Icons.qr_code_scanner,
                    label: 'Barcode scanner',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BarcodeScannerScreen(),
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
        icon: const Icon(Icons.arrow_forward),
        color: Colors.grey.shade600,
        onPressed: () => appLogout(),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    const textColor = Color(0xFFF1F2F5);
    const darkShadow = Color.fromARGB(255, 151, 155, 161);
    const lightShadow = Colors.white;

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
          userName ?? '',
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
        margin: const EdgeInsets.symmetric(vertical: 6),
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
