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

//druga
// import 'package:digitalisapp/core/utils/logout_util.dart';
// import 'package:digitalisapp/features/scanner/warehouse_scanner_controller.dart';
// import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
// import 'package:digitalisapp/services/offline_services.dart';
// import 'package:digitalisapp/models/offline_status_widget.dart';
// import 'package:flutter/material.dart';

// class WarehouseDashboard extends StatefulWidget {
//   const WarehouseDashboard({super.key});

//   @override
//   State<WarehouseDashboard> createState() => _WarehouseDashboardState();
// }

// class _WarehouseDashboardState extends State<WarehouseDashboard> {
//   final _offlineService = OfflineService();
//   bool _isSyncing = false;

//   Future<void> _syncData() async {
//     setState(() {
//       _isSyncing = true;
//     });

//     final success = await _offlineService.syncNow();

//     if (mounted) {
//       setState(() {
//         _isSyncing = false;
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             success
//                 ? 'Sinhronizacija uspješna'
//                 : 'Greška prilikom sinhronizacije',
//           ),
//         ),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Warehouse Dashboard'),
//         actions: [
//           _isSyncing
//               ? const Padding(
//                   padding: EdgeInsets.all(8.0),
//                   child: SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.white,
//                     ),
//                   ),
//                 )
//               : IconButton(
//                   icon: const Icon(Icons.sync),
//                   tooltip: 'Sync data',
//                   onPressed: _syncData,
//                 ),
//           IconButton(
//             icon: const Icon(Icons.logout),
//             tooltip: 'Logout',
//             onPressed: () {
//               appLogout();
//             },
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Offline status banner
//           OfflineStatusWidget(onSyncPressed: _syncData),

//           // Main content
//           Expanded(
//             child: Center(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   ElevatedButton(
//                     child: const Text("Make Shelf Label"),
//                     onPressed: () {
//                       // Log activity
//                       _offlineService.logActivity(
//                         typeId: OfflineService.WAREHOUSE_SHELF,
//                         description: 'Started shelf label creation',
//                       );

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (ctx) => WarehouseScannerScreen(
//                             mode: WarehouseScanMode.createShelf,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 24),
//                   ElevatedButton(
//                     child: const Text("Organize (Assign Products)"),
//                     onPressed: () {
//                       // Log activity
//                       _offlineService.logActivity(
//                         typeId: OfflineService.WAREHOUSE_PRODUCT,
//                         description: 'Started shelf organization',
//                       );

//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (ctx) => WarehouseScannerScreen(
//                             mode: WarehouseScanMode.organize,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                   const SizedBox(height: 24),
//                   ElevatedButton(
//                     child: const Text("Find Product/Shelf"),
//                     onPressed: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (ctx) => WarehouseScannerScreen(
//                             mode: WarehouseScanMode.find,
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// ZAMIJENI warehouse_dashboard.dart CONTENT S OVIM:

import 'package:digitalisapp/core/utils/logout_util.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:digitalisapp/models/offline_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WarehouseDashboard extends StatefulWidget {
  const WarehouseDashboard({super.key});

  @override
  State<WarehouseDashboard> createState() => _WarehouseDashboardState();
}

class _WarehouseDashboardState extends State<WarehouseDashboard> {
  final _offlineService = OfflineService();
  final SessionManager _sessionManager = SessionManager();

  bool _isSyncing = false;
  bool _isLoading = true;

  // User data
  String _userName = '';
  String _userLevel = '';
  List<String> _allowedMagacini = ['333'];
  bool _hasFullAccess = false;

  // Mock warehouse data (since we don't have real API)
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final userData = await _sessionManager.getUser();
      if (userData == null) {
        appLogout();
        return;
      }

      _userName = userData['name'] ?? 'Unknown User';
      _userLevel = userData['level'] ?? 'unknown';

      // 🔥 TRY TO GET PERMISSIONS FROM SESSION
      await _loadPermissions();

      // 🔥 LOAD MOCK PRODUCTS DATA
      _loadMockProducts();
    } catch (e) {
      print('❌ Error loading user data: $e');
      _showError('Error loading data: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadPermissions() async {
    try {
      final userData = await _sessionManager.getUser();
      if (userData == null) return;

      // 🔥 POKUŠAJ DOHVATITI PERMISSIONS IZ SESSION-a DIREKTNO
      // Iz tvog primjera: userData će imati opcije ako je spravljeno u SessionManager

      // FALLBACK - koristi osnovne podatke iz session-a
      _hasFullAccess = _userLevel == 'admin'; // ili neka druga logika
      _allowedMagacini = ['101', '334']; // iz tvog primjera

      print('🔑 Using fallback permissions:');
      print('  - Full access: $_hasFullAccess');
      print('  - Allowed magacini: $_allowedMagacini');
      print('  - User level: $_userLevel');
    } catch (e) {
      print('❌ Error loading permissions: $e');
      // FALLBACK
      _hasFullAccess = false;
      _allowedMagacini = ['101', '334']; // iz tvog server response-a
    }
  }

  void _loadMockProducts() {
    // 🔥 MOCK DATA BASED ON YOUR MAGACINI
    _products = [
      {
        'id': 1,
        'naziv': 'Laptop ASUS ROG',
        'barkod': '3838901234567',
        'current_stock': 15.0,
        'wish_stock': 20.0,
        'magacin_id': '333',
        'magacin_naziv': 'Magacin Zenica 1',
      },
      {
        'id': 2,
        'naziv': 'iPhone 15 Pro',
        'barkod': '3838907654321',
        'current_stock': 5.0,
        'wish_stock': 10.0,
        'magacin_id': '334',
        'magacin_naziv': 'Magacin Zenica 2',
      },
      {
        'id': 3,
        'naziv': 'Samsung Galaxy S24',
        'barkod': '3838901111111',
        'current_stock': 8.0,
        'wish_stock': 15.0,
        'magacin_id': '333',
        'magacin_naziv': 'Magacin Zenica 1',
      },
    ];

    // 🔥 FILTER BY USER PERMISSIONS
    if (!_hasFullAccess) {
      _products = _products.where((product) {
        return _allowedMagacini.contains(product['magacin_id']);
      }).toList();
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);

    final success = await _offlineService.syncNow();

    if (mounted) {
      setState(() => _isSyncing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Sinhronizacija uspješna'
                : 'Greška prilikom sinhronizacije',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  bool _canEditWishstock(String magacinId) {
    print(
      '🔍 Permission check: magacin=$magacinId, hasFullAccess=$_hasFullAccess, allowedMagacini=$_allowedMagacini',
    );

    if (_hasFullAccess) {
      print('✅ Full access granted');
      return true;
    }

    final canEdit = _allowedMagacini.contains(magacinId);
    print(
      canEdit
          ? '✅ Access granted for magacin $magacinId'
          : '❌ Access denied for magacin $magacinId',
    );
    return canEdit;
  }

  Future<void> _editWishStock(Map<String, dynamic> product) async {
    if (!_canEditWishstock(product['magacin_id'])) {
      _showError('Nemate dozvolu za uređivanje ovog magacina');
      return;
    }

    final controller = TextEditingController(
      text: product['wish_stock']?.toString() ?? '0',
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Wish Stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product['naziv'] ?? 'Unknown Product'),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Wish Stock',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateWishStock(product['id'], result, product['magacin_id']);
    }
  }

  Future<void> _updateWishStock(
    int productId,
    double newWishStock,
    String magacinId,
  ) async {
    try {
      // Nađi tačan proizvod po id i magacin_id
      final productIndex = _products.indexWhere(
        (p) => p['id'] == productId && p['magacin_id'] == magacinId,
      );
      if (productIndex == -1) {
        throw Exception('Product not found');
      }

      final product = _products[productIndex];
      final magacinIdFromProduct = product['magacin_id']?.toString();

      if (magacinIdFromProduct == null || magacinIdFromProduct.isEmpty) {
        throw Exception('Magacin ID not found for product');
      }

      if (!_canEditWishstock(magacinIdFromProduct)) {
        throw Exception(
          'Nemate dozvolu za uređivanje ovog magacina ($magacinIdFromProduct)',
        );
      }

      print(
        '🔍 DEBUG: Updating wishstock - Product: $productId, Magacin: $magacinIdFromProduct, New Stock: $newWishStock',
      );

      final response = await ApiService.saveWishstockNew(
        aid: productId,
        stockWish: newWishStock,
        magacinId: magacinIdFromProduct,
      );

      print('🔍 DEBUG: API response: $response');

      if (response['success'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Wish stock updated successfully for magacin $magacinIdFromProduct',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Update local data
        setState(() {
          _products[productIndex]['wish_stock'] = newWishStock;
        });
      } else {
        throw Exception(response['message'] ?? 'Update failed');
      }
    } catch (e) {
      print('❌ ERROR: $e');
      _showError('Error updating wish stock: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Warehouse Dashboard')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading user permissions...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Warehouse Dashboard'),
            Text(
              _userName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          _isSyncing
              ? Padding(
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
              : IconButton(icon: Icon(Icons.sync), onPressed: _syncData),
          IconButton(icon: Icon(Icons.logout), onPressed: appLogout),
        ],
      ),
      body: Column(
        children: [
          OfflineStatusWidget(onSyncPressed: _syncData),

          // Permissions info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User: $_userName ($_userLevel)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                ),
                Text(
                  _hasFullAccess
                      ? '🔑 Full warehouse access'
                      : '🔒 Restricted to: ${_allowedMagacini.join(", ")}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _hasFullAccess
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No products available in your assigned magacini',
                          style: GoogleFonts.inter(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      final canEdit = _canEditWishstock(product['magacin_id']);

                      return Card(
                        margin: EdgeInsets.all(8),
                        child: ListTile(
                          title: Text(product['naziv'] ?? 'Unknown'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Barcode: ${product['barkod']}'),
                              Text(
                                'Stock: ${product['current_stock']} / Wish: ${product['wish_stock']}',
                              ),
                              Text('Magacin: ${product['magacin_naziv']}'),
                            ],
                          ),
                          trailing: canEdit
                              ? ElevatedButton(
                                  onPressed: () => _editWishStock(product),
                                  child: Text('Edit'),
                                )
                              : Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'VIEW ONLY',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
