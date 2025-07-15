import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/features/scanner/barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';

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
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final session = SessionManager();
    final userData = await session.getUser();
    print('User in dashboard after restart: $userData');
    setState(() {
      userName = userData?['name'] ?? '';
      firstLogin = userData?['firstLogin'] ?? false;
    });
    if (firstLogin) {
      userData?['firstLogin'] = false;
      await session.saveUser(userData!);
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BarcodeScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skladistar Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => appLogout(),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            userName == null ? 'Učitavanje...' : 'Dobrodošli, $userName!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: Icon(Icons.qr_code_scanner),
            label: Text('Otvori barkod skener'),
            onPressed: _openScanner,
          ),
        ],
      ),
    );
  }
}
