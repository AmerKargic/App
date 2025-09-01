import 'package:flutter/material.dart';
import 'package:digitalisapp/services/driver_api_service.dart';

class RetailScanAcceptScreen extends StatefulWidget {
  final int oid;
  const RetailScanAcceptScreen({required this.oid, super.key});
  @override
  State<RetailScanAcceptScreen> createState() => _RetailScanAcceptScreenState();
}

class _RetailScanAcceptScreenState extends State<RetailScanAcceptScreen> {
  int scanned = 0;
  int requiredCount = 0;
  bool accepting = false;

  Future<void> _handleScan(String code) async {
    final resp = await DriverApiService.retailScanBox(code, oid: widget.oid);
    if (resp['success'] == 1) {
      setState(() {
        scanned = (resp['scanned'] ?? 0) as int;
        requiredCount = (resp['required'] ?? 0) as int;
      });
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'OK')));
  }

  Future<void> _accept() async {
    setState(() => accepting = true);
    final resp = await DriverApiService.retailAccept(widget.oid);
    setState(() => accepting = false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'OK')));
    if (resp['success'] == 1) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canAccept =
        requiredCount > 0 && scanned >= requiredCount && !accepting;
    return Scaffold(
      appBar: AppBar(title: Text('Accept order #${widget.oid}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),
                title: Text('Boxes scanned: $scanned / $requiredCount'),
                subtitle: const Text('Scan KU{box}KU{oid} codes'),
              ),
            ),
            const SizedBox(height: 16),

            // Replace this with YOUR existing scanner screen/callback:
            // final code = await Navigator.push(context, MaterialPageRoute(builder: (_) => YourScannerScreen()));
            // if (code != null) await _handleScan(code);
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Open scanner'),
              onPressed: () async {
                // Temporary: prompt manual input for quick testing
                final ctrl = TextEditingController(text: 'KU1KU${widget.oid}');
                final code = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Enter test code'),
                    content: TextField(controller: ctrl),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
                if (code != null && code.isNotEmpty) {
                  await _handleScan(code);
                }
              },
            ),

            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text('Accept order'),
              onPressed: canAccept ? _accept : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
