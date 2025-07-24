import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:flutter/material.dart';

class WarehouseDashboard extends StatelessWidget {
  const WarehouseDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              appLogout();
            },
          ),
        ],
      ),

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              child: const Text("Make Shelf Label"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => WarehouseScannerScreen(
                      mode: WarehouseScanMode.createShelf,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              child: const Text("Organize (Assign Products)"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => WarehouseScannerScreen(
                      mode: WarehouseScanMode.organize,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              child: const Text("Find Product/Shelf"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) =>
                        WarehouseScannerScreen(mode: WarehouseScanMode.find),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
