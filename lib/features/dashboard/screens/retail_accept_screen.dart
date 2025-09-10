// import 'package:digitalisapp/features/maps/driver_navigation_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:digitalisapp/services/driver_api_service.dart';

// class RetailScanAcceptScreen extends StatefulWidget {
//   final int oid;
//   const RetailScanAcceptScreen({required this.oid, super.key});
//   @override
//   State<RetailScanAcceptScreen> createState() => _RetailScanAcceptScreenState();
// }

// class _RetailScanAcceptScreenState extends State<RetailScanAcceptScreen> {
//   int scanned = 0;
//   int requiredCount = 0;
//   bool accepting = false;

//   Future<void> _handleScan(String code) async {
//     // Pretpostavljamo da je kod formata KU{boxNumber}KU{oid}
//     final reg = RegExp(r'^KU(\d+)KU(\d+)$');
//     final match = reg.firstMatch(code);
//     if (match == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Invalid code format!')));
//       return;
//     }
//     final boxNumber = int.tryParse(match.group(1) ?? '');
//     final oid = int.tryParse(match.group(2) ?? '');
//     if (boxNumber == null || oid == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text('Invalid code data!')));
//       return;
//     }

//     final resp = await DriverApiService.retailScanBox(oid, boxNumber);
//     if (resp['success'] == 1) {
//       setState(() {
//         scanned = (resp['scanned'] ?? 0) as int;
//         requiredCount = (resp['required'] ?? 0) as int;
//       });
//     }
//     if (!mounted) return;
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'OK')));
//   }

//   Future<void> _accept() async {
//     setState(() => accepting = true);
//     final resp = await DriverApiService.retailAccept(widget.oid);
//     setState(() => accepting = false);
//     if (!mounted) return;
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text(resp['message'] ?? 'OK')));
//     if (resp['success'] == 1) Navigator.of(context).pop();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final canAccept =
//         requiredCount > 0 && scanned >= requiredCount && !accepting;
//     return Scaffold(
//       appBar: AppBar(title: Text('Accept order #${widget.oid}')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Card(
//               child: ListTile(
//                 leading: const Icon(Icons.inventory),
//                 title: Text('Boxes scanned: $scanned / $requiredCount'),
//                 subtitle: const Text('Scan KU{box}KU{oid} codes'),
//               ),
//             ),
//             const SizedBox(height: 16),

//             ElevatedButton.icon(
//               icon: const Icon(Icons.qr_code_scanner),
//               label: const Text('Open scanner'),
//               onPressed: () async {
//                 final code = await Navigator.push(
//                   context,
//                   MaterialPageRoute(builder: (_) => DriverOrderScanScreen()),
//                 );
//                 if (code != null) await _handleScan(code);

//                 // Temporary: prompt manual input for quick testing
//                 final ctrl = TextEditingController(text: 'KU1KU${widget.oid}');

//                 if (code != null && code.isNotEmpty) {
//                   await _handleScan(code);
//                 }
//               },
//             ),

//             const Spacer(),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.check_circle),
//               label: const Text('Accept order'),
//               onPressed: canAccept ? _accept : null,
//               style: ElevatedButton.styleFrom(
//                 minimumSize: const Size.fromHeight(48),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:digitalisapp/features/maps/driver_navigation_screen.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/driver_api_service.dart';

class RetailScanAcceptScreen extends StatefulWidget {
  final int oid;
  final String mode; // 'retail' or 'return'
  const RetailScanAcceptScreen({
    required this.oid,
    this.mode = 'retail',
    super.key,
  });
  @override
  State<RetailScanAcceptScreen> createState() => _RetailScanAcceptScreenState();
}

class _RetailScanAcceptScreenState extends State<RetailScanAcceptScreen> {
  int scanned = 0;
  int requiredCount = 0;
  bool accepting = false;

  Future<void> _handleScan(String code) async {
    final reg = RegExp(r'^KU(\d+)KU(\d+)$');
    final match = reg.firstMatch(code);
    if (match == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid code format!')));
      return;
    }
    final boxNumber = int.tryParse(match.group(1) ?? '');
    final oid = int.tryParse(match.group(2) ?? '');
    if (boxNumber == null || oid == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid code data!')));
      return;
    }

    Map<String, dynamic> resp;
    if (widget.mode == 'return') {
      resp = await DriverApiService.returnScanBox(oid, boxNumber);
    } else {
      resp = await DriverApiService.retailScanBox(oid, boxNumber);
    }
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
    Map<String, dynamic> resp;
    if (widget.mode == 'return') {
      resp = await DriverApiService.returnAccept(widget.oid);
    } else {
      resp = await DriverApiService.retailAccept(widget.oid);
    }
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
      appBar: AppBar(
        title: Text(
          widget.mode == 'return'
              ? 'Accept return #${widget.oid}'
              : 'Accept order #${widget.oid}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.inventory),
                title: Text('Boxes scanned: $scanned / $requiredCount'),
                subtitle: Text(
                  widget.mode == 'return'
                      ? 'Scan return box codes (KU{box}KU{oid})'
                      : 'Scan retail box codes (KU{box}KU{oid})',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                widget.mode == 'return'
                    ? 'Open return scanner'
                    : 'Open scanner',
              ),
              onPressed: () async {
                final code = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DriverOrderScanScreen()),
                );
                if (code != null && code.isNotEmpty) await _handleScan(code);
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: Text(
                widget.mode == 'return' ? 'Accept return' : 'Accept order',
              ),
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
