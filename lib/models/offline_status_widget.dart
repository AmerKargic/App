import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineStatusWidget extends StatefulWidget {
  final VoidCallback? onSyncPressed;

  const OfflineStatusWidget({Key? key, this.onSyncPressed}) : super(key: key);

  @override
  _OfflineStatusWidgetState createState() => _OfflineStatusWidgetState();
}

class _OfflineStatusWidgetState extends State<OfflineStatusWidget> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    // Check initial state
    Connectivity().checkConnectivity().then((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });

    // Listen for changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: _isOnline ? Colors.green.shade100 : Colors.orange.shade100,
      child: Row(
        children: [
          Icon(
            _isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: _isOnline ? Colors.green.shade800 : Colors.orange.shade800,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline mode',
            style: TextStyle(
              color: _isOnline ? Colors.green.shade800 : Colors.orange.shade800,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          if (widget.onSyncPressed != null)
            InkWell(
              onTap: _isOnline ? widget.onSyncPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.sync,
                      color: _isOnline ? Colors.green.shade800 : Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sync now',
                      style: TextStyle(
                        color: _isOnline ? Colors.green.shade800 : Colors.grey,
                        fontSize: 12,
                      ),
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
