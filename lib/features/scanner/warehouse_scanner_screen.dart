import 'package:digitalisapp/features/scanner/driver_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'warehouse_scanner_controller.dart';

class HardwareBarcodeInput extends StatefulWidget {
  final void Function(String barcode) onBarcodeScanned;
  final String hintText;
  const HardwareBarcodeInput({
    super.key,
    required this.onBarcodeScanned,
    this.hintText = "Scan barcode",
  });

  @override
  State<HardwareBarcodeInput> createState() => _HardwareBarcodeInputState();
}

class _HardwareBarcodeInputState extends State<HardwareBarcodeInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleBarcode(String code) {
    final trimmedCode = code.trim();
    if (trimmedCode.isNotEmpty) {
      // Add haptic feedback like in your barcode scanner
      HapticFeedback.mediumImpact();

      // Call the callback
      widget.onBarcodeScanned(trimmedCode);

      // Clear the field for next scan
      _controller.clear();

      // Ensure focus stays on the input for continuous scanning
      if (mounted) {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: true,
      decoration: InputDecoration(
        labelText: widget.hintText,
        border: const OutlineInputBorder(),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Add camera icon button
            IconButton(
              icon: Icon(Icons.camera_alt, color: Colors.blue),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => VozacScannerScreen(
                      onBarcodeDetected: widget.onBarcodeScanned,
                    ),
                  ),
                );
              },
              tooltip: 'Skeniraj kamerom',
            ),
            // Keep the existing QR code icon
            // Icon(Icons.qr_code_scanner),
          ],
        ),
      ),
      onSubmitted: _handleBarcode,
      onChanged: (value) {
        // Auto-submit when typical barcode length is reached
        // Most barcodes are 8, 12, or 13 digits
        if (value.length >= 8 &&
            (value.length == 8 || value.length == 12 || value.length == 13)) {
          // Small delay to ensure the full barcode is captured
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted && _controller.text == value) {
              _handleBarcode(value);
            }
          });
        }
      },
    );
  }
}

// Main scanner screen - keeping your existing implementation
class WarehouseScannerScreen extends StatelessWidget {
  final WarehouseScanMode mode;
  const WarehouseScannerScreen({super.key, required this.mode});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          WarehouseScannerController(api: Provider.of(context, listen: false)),
      child: _WarehouseScannerBody(mode: mode),
    );
  }
}

class _WarehouseScannerBody extends StatelessWidget {
  final WarehouseScanMode mode;
  const _WarehouseScannerBody({required this.mode});

  @override
  Widget build(BuildContext context) {
    final ctrl = Provider.of<WarehouseScannerController>(context);

    if (mode == WarehouseScanMode.createShelf) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Create Shelf"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Shelf name"),
                onChanged: ctrl.setShelfName,
              ),
              const SizedBox(height: 20),
              ctrl.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      child: const Text("Generate & Print Label"),
                      onPressed: () => ctrl.createShelf(),
                    ),
              if (ctrl.errorMessage.isNotEmpty)
                Text(
                  ctrl.errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              if (ctrl.createdShelf != null)
                Column(
                  children: [
                    Text("Shelf label created:"),
                    Text(
                      ctrl.createdShelf!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text("Barcode: ${ctrl.createdShelf!.barcode}"),
                  ],
                ),
            ],
          ),
        ),
      );
    } else if (mode == WarehouseScanMode.organize) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Organize Shelf"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Scan shelf barcode:"),
              HardwareBarcodeInput(
                hintText: "Scan shelf barcode",
                onBarcodeScanned: (barcode) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await ctrl.scanShelfBarcode(barcode);
                  });
                },
              ),
              if (ctrl.scannedShelfId != null) ...[
                Text("Shelf scanned: ${ctrl.scannedShelfBarcode}"),
                const Divider(),
                const Text("Now scan products for this shelf:"),
                HardwareBarcodeInput(
                  hintText: "Scan product barcode...",
                  onBarcodeScanned: (barcode) async {
                    // Lookup product, then add to scan list
                    // You need to add your product lookup logic here:
                    // e.g., call API, then ctrl.addProductToScan(productId, productName);
                  },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: ctrl.scannedProductNames
                      .map((name) => Chip(label: Text(name)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  child: const Text("Save products on this shelf"),
                  onPressed: () async {
                    final ok = await ctrl.saveProductsOnShelf();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ok ? "Saved!" : "Failed to save")),
                    );
                  },
                ),
              ],
              if (ctrl.errorMessage.isNotEmpty)
                Text(
                  ctrl.errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
      );
    } else if (mode == WarehouseScanMode.find) {
      return Scaffold(
        appBar: AppBar(title: const Text("Find Product")),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              HardwareBarcodeInput(
                hintText: "Enter or scan product barcode",
                onBarcodeScanned: (ean) async {
                  // Lookup shelf by product barcode and show result
                  // e.g., ctrl.findShelfForProduct(ean);
                },
              ),
              // You can add a widget here to show the shelf info result
            ],
          ),
        ),
      );
    } else {
      return const SizedBox();
    }
  }
}
