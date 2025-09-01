import 'package:digitalisapp/core/utils/update_checker.dart';
import 'package:digitalisapp/features/dashboard/screens/pending_orders_screen.dart';
import 'package:digitalisapp/features/products/screens/product_screen.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:digitalisapp/widgets/notifications.dart';
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

                  // Top welcome + we keep your design
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Expanded(child: _buildWelcomeHeader())],
                  ),

                  const Spacer(),

                  // Existing buttons
                  _buildNeumorphicButton(
                    icon: Icons.inventory,
                    label: 'Warehouse',
                    onTap: () {
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
                    },
                    child: null,
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
                    child: null,
                  ),

                  const SizedBox(height: 20),

                  // New: Pending retail orders quick access
                  _buildNeumorphicButton(
                    icon: Icons.assignment_turned_in,
                    label: 'Pending retail orders',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RetailPendingOrdersScreen(),
                        ),
                      );
                    },
                    child: null,
                  ),

                  const SizedBox(height: 12),

                  // Optional: small debug helpers
                  Row(
                    children: [
                      Expanded(
                        child: _buildNeumorphicButton(
                          icon: Icons.notifications_active,
                          label: 'Debug: Open pending',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const RetailPendingOrdersScreen(),
                              ),
                            );
                          },
                          child: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildNeumorphicButton(
                          icon: Icons.bug_report,
                          label: 'Debug: Send retail req',
                          onTap: () async {
                            // Ask for OID and trigger requestRetailApproval
                            final ctrl = TextEditingController();
                            final oidStr = await showDialog<String>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Enter OID'),
                                content: TextField(
                                  controller: ctrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'e.g. 12345',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(ctx, ctrl.text.trim()),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            if (!mounted || oidStr == null || oidStr.isEmpty)
                              return;
                            final oid = int.tryParse(oidStr) ?? 0;
                            if (oid <= 0) return;
                            final resp =
                                await DriverApiService.requestRetailApproval(
                                  oid,
                                );
                            final msg = resp['message'] ?? 'Sent';
                            if (!mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(msg)));
                          },
                          child: null,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),
                ],
              ),
            ),

            // Top-right actions: Notification bell + Logout, preserving your neumorphic style
            Positioned(
              top: 16,
              right: 16,
              child: IntrinsicWidth(
                // ensure the Row gets laid out with its natural width
                child: _buildTopRightActions(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New: top-right actions container with bell and logout
  Widget _buildTopRightActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildNeumorphicButton(
          icon: Icons.notifications,
          label: 'Notifications',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RetailPendingOrdersScreen(),
              ),
            );
          },
          child: const NotificationBell(), // now actually rendered
          expand: false, // IMPORTANT: compact mode inside a Row
        ),
        const SizedBox(width: 10),
        _buildLogoutButton(),
      ],
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
    Widget? child,
    bool expand = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: expand ? double.infinity : null,
          constraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 48,
          ), // ensure tappable size
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
          child: child != null
              ? ConstrainedBox(
                  // force layout for custom child (e.g., NotificationBell)
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 24,
                  ),
                  child: Align(alignment: Alignment.centerLeft, child: child),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}
