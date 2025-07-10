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

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final session = SessionManager();
    final userData = await session.getUser();
    setState(() {
      userName = userData?['name'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skladistar Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () {
              // tvoj logout kod
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Text(
          userName == null ? 'Učitavanje...' : 'Dobrodošli, $userName!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
