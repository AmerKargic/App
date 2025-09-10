// import 'dart:convert';
// import 'package:digitalisapp/features/dashboard/screens/retail_accept_screen.dart';
// import 'package:digitalisapp/services/offline_services.dart';
// import 'package:flutter/material.dart';
// import 'package:digitalisapp/services/driver_api_service.dart';

// class RetailPendingOrdersScreen extends StatefulWidget {
//   const RetailPendingOrdersScreen({super.key});
//   @override
//   State<RetailPendingOrdersScreen> createState() =>
//       _RetailPendingOrdersScreenState();
// }

// class _RetailPendingOrdersScreenState extends State<RetailPendingOrdersScreen> {
//   Future<List<Map<String, dynamic>>> _load() async {
//     final resp = await DriverApiService.getPendingForRetail();
//     if (resp['success'] == 1) {
//       final list = (resp['items'] as List).cast<Map<String, dynamic>>();
//       return list;
//     }
//     return [];
//   }

//   int _oidFromPayload(Map<String, dynamic> n) {
//     try {
//       final payloadStr = (n['payload_json'] ?? '{}') as String;
//       final map = json.decode(payloadStr) as Map<String, dynamic>;
//       return int.tryParse('${map['oid'] ?? 0}') ?? 0;
//     } catch (_) {
//       return 0;
//     }
//   }

//   final OfflineService _offlineService = OfflineService();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Pending orders')),
//       body: FutureBuilder<List<Map<String, dynamic>>>(
//         future: _load(),
//         builder: (ctx, snap) {
//           if (!snap.hasData)
//             return const Center(child: CircularProgressIndicator());
//           final items = snap.data!;
//           if (items.isEmpty)
//             return const Center(child: Text('No pending orders'));
//           return ListView.separated(
//             itemCount: items.length,
//             separatorBuilder: (_, __) => const Divider(height: 1),
//             itemBuilder: (ctx, i) {
//               final n = items[i];
//               final oid = _oidFromPayload(n);
//               return ListTile(
//                 title: Text('Order ${n['oid']}'),
//                 subtitle: Text(
//                   'Magacin: ${n['mag2_id']}, Kutije: ${n['br_kutija']}',
//                 ),
//                 trailing: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.check_circle, color: Colors.green),
//                       tooltip: 'Odobri narudžbu',
//                       onPressed: () async {
//                         final resp = await DriverApiService.retailAccept(
//                           n['oid'],
//                         );
//                         print('RAW RESPONSE retailAccept: "${resp}"');
//                         await _offlineService.logActivity(
//                           typeId: OfflineService.RETAIL_ACCEPTED,
//                           description: 'Retail order accepted',
//                           relatedId: n['oid'],
//                           extraData: {
//                             'mag2_id': n['mag2_id'],
//                             'timestamp': DateTime.now().toIso8601String(),
//                             'response': resp,
//                           },
//                         );
//                         if (!context.mounted) return;
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text(
//                               resp['success'] == 1
//                                   ? 'Narudžba odobrena!'
//                                   : 'Greška: ${resp['message']}',
//                             ),
//                           ),
//                         );
//                         setState(() {}); // Refresh liste
//                       },
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.qr_code_scanner),
//                       tooltip: 'Skeniraj',
//                       onPressed: () async {
//                         if (n['id'] != null) {
//                           await DriverApiService.markNotificationRead(
//                             (n['id'] as num).toInt(),
//                           );
//                         }
//                         if (!context.mounted) return;
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                             builder: (_) =>
//                                 RetailScanAcceptScreen(oid: n['oid']),
//                           ),
//                         );
//                       },
//                     ),
//                     IconButton(
//                       icon: const Icon(Icons.bug_report, color: Colors.red),
//                       tooltip: 'Debug scan box (retail)',
//                       onPressed: () async {
//                         final boxNumber =
//                             1; // ili izaberi broj kutije koju želiš simulirati
//                         final resp = await DriverApiService.retailScanBox(
//                           n['oid'],
//                           boxNumber,
//                         );
//                         await _offlineService.logActivity(
//                           typeId: OfflineService.RETAIL_SCANNED_BOX,
//                           description: 'Retail scan started',
//                           relatedId: n['oid'],
//                           extraData: {
//                             'mag2_id': n['mag2_id'],
//                             'timestamp': DateTime.now().toIso8601String(),
//                           },
//                         );
//                         print('Retail scan response: $resp');
//                         print(
//                           'DEBUG RETAIL SCAN: oid=${n['oid']} box=$boxNumber => $resp',
//                         );
//                         if (!context.mounted) return;
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text(
//                               resp['success'] == 1
//                                   ? 'Retail scan successful!'
//                                   : 'Retail scan failed: ${resp['message']}',
//                             ),
//                           ),
//                         );
//                         setState(() {});
//                       },
//                     ),
//                   ],
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:digitalisapp/features/dashboard/screens/retail_accept_screen.dart';
import 'package:digitalisapp/services/offline_services.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/driver_api_service.dart';

class RetailPendingOrdersScreen extends StatefulWidget {
  final String mode; // 'retail' or 'return'
  const RetailPendingOrdersScreen({this.mode = 'retail', super.key});
  @override
  State<RetailPendingOrdersScreen> createState() =>
      _RetailPendingOrdersScreenState();
}

class _RetailPendingOrdersScreenState extends State<RetailPendingOrdersScreen> {
  Future<List<Map<String, dynamic>>> _load() async {
    Map<String, dynamic> resp;
    if (widget.mode == 'return') {
      resp = await DriverApiService.getPendingReturns();
    } else {
      resp = await DriverApiService.getPendingForRetail();
    }
    if (resp['success'] == 1) {
      final list = (resp['items'] as List).cast<Map<String, dynamic>>();
      return list;
    }
    return [];
  }

  int _oidFromPayload(Map<String, dynamic> n) {
    try {
      final payloadStr = (n['payload_json'] ?? '{}') as String;
      final map = json.decode(payloadStr) as Map<String, dynamic>;
      return int.tryParse('${map['oid'] ?? 0}') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  final OfflineService _offlineService = OfflineService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == 'return' ? 'Pending returns' : 'Pending orders',
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty)
            return Center(
              child: Text(
                widget.mode == 'return'
                    ? 'No pending returns'
                    : 'No pending orders',
              ),
            );
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final n = items[i];
              final oid = n['oid'] ?? _oidFromPayload(n);
              return ListTile(
                title: Text(
                  widget.mode == 'return' ? 'Return $oid' : 'Order $oid',
                ),
                subtitle: Text(
                  'Magacin: ${n['mag2_id'] ?? ''}, Kutije: ${n['br_kutija'] ?? ''}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.check_circle,
                        color: widget.mode == 'return'
                            ? Colors.blue
                            : Colors.green,
                      ),
                      tooltip: widget.mode == 'return'
                          ? 'Prihvati povrat'
                          : 'Odobri narudžbu',
                      onPressed: () async {
                        Map<String, dynamic> resp;
                        if (widget.mode == 'return') {
                          resp = await DriverApiService.returnAccept(n['oid']);
                        } else {
                          resp = await DriverApiService.retailAccept(n['oid']);
                        }
                        await _offlineService.logActivity(
                          typeId: widget.mode == 'return'
                              ? OfflineService.RETURN_ACCEPTED
                              : OfflineService.RETAIL_ACCEPTED,
                          description: widget.mode == 'return'
                              ? 'Return accepted'
                              : 'Retail order accepted',
                          relatedId: n['oid'],
                          extraData: {
                            'mag2_id': n['mag2_id'],
                            'timestamp': DateTime.now().toIso8601String(),
                            'response': resp,
                          },
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              resp['success'] == 1
                                  ? (widget.mode == 'return'
                                        ? 'Povrat prihvaćen!'
                                        : 'Narudžba odobrena!')
                                  : 'Greška: ${resp['message']}',
                            ),
                          ),
                        );
                        setState(() {}); // Refresh liste
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: widget.mode == 'return'
                          ? 'Skeniraj povrat'
                          : 'Skeniraj',
                      onPressed: () async {
                        if (n['id'] != null) {
                          await DriverApiService.markNotificationRead(
                            (n['id'] as num).toInt(),
                          );
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RetailScanAcceptScreen(
                              oid: n['oid'],
                              mode: widget.mode,
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.bug_report,
                        color: widget.mode == 'return'
                            ? Colors.blue
                            : Colors.red,
                      ),
                      tooltip: widget.mode == 'return'
                          ? 'Debug scan box (return)'
                          : 'Debug scan box (retail)',
                      onPressed: () async {
                        final boxNumber = 1;
                        Map<String, dynamic> resp;
                        if (widget.mode == 'return') {
                          resp = await DriverApiService.returnScanBox(
                            n['oid'],
                            boxNumber,
                          );
                        } else {
                          resp = await DriverApiService.retailScanBox(
                            n['oid'],
                            boxNumber,
                          );
                        }
                        await _offlineService.logActivity(
                          typeId: widget.mode == 'return'
                              ? OfflineService.RETURN_SCANNED_BOX
                              : OfflineService.RETAIL_SCANNED_BOX,
                          description: widget.mode == 'return'
                              ? 'Return scan started'
                              : 'Retail scan started',
                          relatedId: n['oid'],
                          extraData: {
                            'mag2_id': n['mag2_id'],
                            'timestamp': DateTime.now().toIso8601String(),
                          },
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              resp['success'] == 1
                                  ? (widget.mode == 'return'
                                        ? 'Return scan successful!'
                                        : 'Retail scan successful!')
                                  : (widget.mode == 'return'
                                        ? 'Return scan failed: ${resp['message']}'
                                        : 'Retail scan failed: ${resp['message']}'),
                            ),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
