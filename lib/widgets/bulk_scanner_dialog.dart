import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class BulkScannerDialog extends StatefulWidget {
  final Function(List<String>) onBarcodesScanned;
  final VoidCallback onCancel;

  const BulkScannerDialog({
    Key? key,
    required this.onBarcodesScanned,
    required this.onCancel,
  }) : super(key: key);

  @override
  _BulkScannerDialogState createState() => _BulkScannerDialogState();
}

class _BulkScannerDialogState extends State<BulkScannerDialog> {
  MobileScannerController controller = MobileScannerController();
  Set<String> scannedCodes = {};
  Timer? autoSubmitTimer;
  Map<int, List<String>> orderBoxes = {}; // Track boxes by order

  @override
  void initState() {
    super.initState();
    _resetAutoSubmitTimer();
  }

  void _resetAutoSubmitTimer() {
    autoSubmitTimer?.cancel();
    autoSubmitTimer = Timer(Duration(seconds: 5), () {
      if (scannedCodes.isNotEmpty) {
        _submitScannedCodes();
      }
    });
  }

  void _submitScannedCodes() {
    controller.dispose();
    widget.onBarcodesScanned(scannedCodes.toList());
  }

  void _processBarcode(String code) {
    if (scannedCodes.contains(code)) return;

    // Parse order ID from barcode
    RegExp regex = RegExp(r'^KU(\d+)KU(\d+)$');
    final match = regex.firstMatch(code);

    if (match != null) {
      final boxNumber = int.parse(match.group(1)!);
      final orderId = int.parse(match.group(2)!);

      orderBoxes[orderId] ??= [];
      orderBoxes[orderId]!.add(code);

      setState(() {
        scannedCodes.add(code);
      });

      _resetAutoSubmitTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.orange,
              child: Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "BULK SCAN MODE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    "${scannedCodes.length}",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Instructions
            Container(
              padding: EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Text(
                "📦 Scan multiple barcodes quickly!\n⏱️ Auto-submits after 5 seconds of inactivity",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ),

            // Scanner
            Expanded(
              flex: 3,
              child: MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _processBarcode(barcode.rawValue!);
                    }
                  }
                },
              ),
            ),

            // Summary by order
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Scanned by Order (${orderBoxes.length} orders):",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: orderBoxes.length,
                        itemBuilder: (context, index) {
                          final orderId = orderBoxes.keys.elementAt(index);
                          final boxes = orderBoxes[orderId]!;
                          return Container(
                            margin: EdgeInsets.only(bottom: 4),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Order #$orderId: ${boxes.length} boxes",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Buttons
            Container(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        controller.dispose();
                        widget.onCancel();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                      child: Text("Cancel"),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: scannedCodes.isNotEmpty
                          ? _submitScannedCodes
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: Text("Process ${scannedCodes.length} Codes"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    autoSubmitTimer?.cancel();
    controller.dispose();
    super.dispose();
  }
}
