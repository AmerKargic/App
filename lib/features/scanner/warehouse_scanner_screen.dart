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
  String _buffer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            final code = _controller.text.trim();
            if (code.isNotEmpty) {
              widget.onBarcodeScanned(code);
              _controller.clear();
              _buffer = '';
            }
          } else if (event.character != null && event.character != '') {
            _buffer += event.character!;
            _controller.text = _buffer;
          }
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (code) {
          widget.onBarcodeScanned(code.trim());
          _controller.clear();
          _buffer = '';
        },
      ),
    );
  }
}

// Main scanner screen
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
        appBar: AppBar(title: const Text("Create Shelf Label")),
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
        appBar: AppBar(title: const Text("Organize Shelf")),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text("Scan shelf barcode:"),
              HardwareBarcodeInput(
                hintText: "Scan shelf barcode",
                onBarcodeScanned: (barcode) async {
                  await ctrl.scanShelfBarcode(barcode);
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
