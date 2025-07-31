// import 'package:digitalisapp/core/utils/logout_util.dart';
// import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
// import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
// import 'package:flutter/material.dart';

// class WarehouseDashboard extends StatelessWidget {
//   const WarehouseDashboard({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Warehouse Dashboard'),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             tooltip: 'Logout',
//             onPressed: () {
//               appLogout();
//             },
//           ),
//         ],
//       ),

//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             ElevatedButton(
//               child: const Text("Make Shelf Label"),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (ctx) => WarehouseScannerScreen(
//                       mode: WarehouseScanMode.createShelf,
//                     ),
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               child: const Text("Organize (Assign Products)"),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (ctx) => WarehouseScannerScreen(
//                       mode: WarehouseScanMode.organize,
//                     ),
//                   ),
//                 );
//               },
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               child: const Text("Find Product/Shelf"),
//               onPressed: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (ctx) =>
//                         WarehouseScannerScreen(mode: WarehouseScanMode.find),
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:digitalisapp/models/offline_status_widget.dart';
import 'package:flutter/material.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  final _offlineService = OfflineService();
  bool _isSyncing = false;

  Future<void> _syncData() async {
    setState(() {
      _isSyncing = true;
    });

    final success = await _offlineService.syncNow();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Sinhronizacija uspješna'
                : 'Greška prilikom sinhronizacije',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Dashboard'),
        actions: [
          _isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: 'Sync data',
                  onPressed: _syncData,
                ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              appLogout();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline status banner
          OfflineStatusWidget(onSyncPressed: _syncData),

          // Main content
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    child: const Text("Make Shelf Label"),
                    onPressed: () {
                      // Log activity
                      _offlineService.logActivity(
                        typeId: OfflineService.WAREHOUSE_SHELF,
                        description: 'Started shelf label creation',
                      );

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
                      // Log activity
                      _offlineService.logActivity(
                        typeId: OfflineService.WAREHOUSE_PRODUCT,
                        description: 'Started shelf organization',
                      );

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
                          builder: (ctx) => WarehouseScannerScreen(
                            mode: WarehouseScanMode.find,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
