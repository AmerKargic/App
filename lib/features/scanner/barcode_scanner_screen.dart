import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'barcode_scanner_controller.dart';

class BarcodeScannerScreen extends StatelessWidget {
  final BarcodeScannerController controller = Get.put(
    BarcodeScannerController(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Skeniraj barkod'),
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report),
            tooltip: 'Test scan (for emulator)',
            onPressed: () {
              controller.fetchProduct("5453001045986"); // real EAN
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: MobileScanner(
              onDetect: (capture) {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode != null && controller.isLoading.isFalse) {
                  controller.fetchProduct(barcode);
                }
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (controller.error.isNotEmpty) {
                return Center(
                  child: Text(
                    controller.error.value,
                    style: TextStyle(color: Colors.red),
                  ),
                );
              }

              if (controller.productInfo.isEmpty) {
                return Center(child: Text('Skenirajte barkod proizvoda.'));
              }

              final product = controller.productInfo;
              final wishstocks = List<Map>.from(product['wishstock'] ?? []);

              return ListView(
                padding: EdgeInsets.all(16),
                children: [
                  if ((product['image'] ?? '').isNotEmpty)
                    Image.network(product['image'], height: 150),
                  Text(
                    'Naziv: ${product['name'] ?? ''}',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text('EAN: ${product['EAN'] ?? ''}'),
                  Text('Cijena (na rate): ${product['MPC'] ?? ''}'),
                  Text(
                    'Cijena (jednokratno): ${product['MPC_jednokratno'] ?? ''}',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Stanja po poslovnicama:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...wishstocks.asMap().entries.map((entry) {
                    final i = entry.key;
                    final w = entry.value;
                    final locked = w['stock_wish_locked'] == 1;
                    final canChange = controller.canEditWishstock(w);

                    return Card(
                      child: ListTile(
                        title: Text(w['name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Stanje: ${w['stock']}'),
                            Text('Željeno: ${w['stock_wish']}'),
                          ],
                        ),
                        trailing: locked
                            ? const Icon(Icons.lock, color: Colors.red)
                            : canChange
                            ? IconButton(
                                icon: Icon(Icons.edit, color: Colors.green),
                                onPressed: () {
                                  _showEditDialog(context, i, w, controller);
                                },
                              )
                            : const Icon(Icons.lock_open, color: Colors.grey),
                      ),
                    );
                  }),
                  if (controller.changedIndexes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text("Sačuvaj izmjene"),
                        onPressed: controller.saveWishstockChanges,
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    int index,
    Map item,
    BarcodeScannerController controller,
  ) {
    final controllerText = TextEditingController(
      text: item['stock_wish'].toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Uredi željeno stanje'),
        content: TextField(
          controller: controllerText,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'Unesi novu vrijednost'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Otkaži'),
          ),
          TextButton(
            onPressed: () {
              final newVal =
                  double.tryParse(controllerText.text) ?? item['stock_wish'];
              controller.updateWishstock(index, newVal);
              Navigator.pop(context);
            },
            child: Text('Spremi'),
          ),
        ],
      ),
    );
  }
}
