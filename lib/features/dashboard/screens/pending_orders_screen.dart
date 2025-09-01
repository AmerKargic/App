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
    final resp = await DriverApiService.getNotifications();
    if (resp['success'] == 1) {
      final list = (resp['notifications'] as List).cast<Map<String, dynamic>>();
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
                title: Text(n['title'] ?? 'Order'),
                subtitle: Text(n['body'] ?? ''),
                trailing: const Icon(Icons.qr_code_scanner),
                onTap: () async {
                  await DriverApiService.markNotificationRead(
                    (n['id'] as num).toInt(),
                  );
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RetailScanAcceptScreen(oid: oid),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
