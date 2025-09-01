import 'dart:async';
import 'package:digitalisapp/features/dashboard/screens/pending_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/driver_api_service.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _count = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _poll();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => _poll());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final resp = await DriverApiService.getNotifications();
      if (!mounted) return;
      setState(() => _count = (resp['notifications'] as List?)?.length ?? 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RetailPendingOrdersScreen(),
              ),
            );
          },
        ),
        if (_count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_count',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }
}
