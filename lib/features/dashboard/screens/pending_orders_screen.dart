import 'dart:convert';
import 'package:digitalisapp/features/dashboard/screens/retail_accept_screen.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/driver_api_service.dart';

class RetailPendingOrdersScreen extends StatefulWidget {
  const RetailPendingOrdersScreen({super.key});
  @override
  State<RetailPendingOrdersScreen> createState() =>
      _RetailPendingOrdersScreenState();
}

class _RetailPendingOrdersScreenState extends State<RetailPendingOrdersScreen> {
  Future<List<Map<String, dynamic>>> _load() async {
    final resp = await DriverApiService.getPendingForRetail();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending orders')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _load(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty)
            return const Center(child: Text('No pending orders'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (ctx, i) {
              final n = items[i];
              final oid = _oidFromPayload(n);
              return ListTile(
                title: Text('Order ${n['oid']}'),
                subtitle: Text(
                  'Magacin: ${n['mag2_id']}, Kutije: ${n['br_kutija']}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      tooltip: 'Odobri narudžbu',
                      onPressed: () async {
                        final resp = await DriverApiService.retailAccept(
                          n['oid'],
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              resp['success'] == 1
                                  ? 'Narudžba odobrena!'
                                  : 'Greška: ${resp['message']}',
                            ),
                          ),
                        );
                        setState(() {}); // Refresh liste
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      tooltip: 'Skeniraj',
                      onPressed: () async {
                        if (n['id'] != null) {
                          await DriverApiService.markNotificationRead(
                            (n['id'] as num).toInt(),
                          );
                        }
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RetailScanAcceptScreen(oid: n['oid']),
                          ),
                        );
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
