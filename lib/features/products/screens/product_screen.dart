import 'package:digitalisapp/core/utils/printer_util.dart';
import 'package:digitalisapp/features/products/controllers/product_controller.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProductsListScreen extends StatefulWidget {
  final int kupId;
  final int posId;
  final ApiService apiService;
  const ProductsListScreen({
    required this.kupId,
    required this.posId,
    required this.apiService,
    super.key,
  });

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

// Put this at the top of your file (after your imports)
Future<void> showPriceTagOptionDialog(
  BuildContext context,
  Function(bool) onSelected,
) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Izaberi opciju'),
        content: Text('Kako želiš isprintati deklaraciju?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cijena bez opisa'),
            onPressed: () {
              Navigator.of(context).pop();
              onSelected(false); // false = without description
            },
          ),
          TextButton(
            child: Text('Cijena s opisom'),
            onPressed: () {
              Navigator.of(context).pop();
              onSelected(true); // true = with description
            },
          ),
          TextButton(
            child: Text('Odustani'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  late final ProductListController controller;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller = ProductListController(
      apiService: widget.apiService,
      kupId: widget.kupId,
      posId: widget.posId,
    );
    controller.fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: Scaffold(
        appBar: AppBar(title: const Text('Proizvodi')),
        body: Consumer<ProductListController>(
          builder: (context, ctrl, _) {
            if (ctrl.loading)
              return const Center(child: CircularProgressIndicator());
            if (ctrl.error != null)
              return Center(child: Text('Greška: ${ctrl.error}'));
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pretraži...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: ctrl.search,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: ctrl.products.length,
                    itemBuilder: (context, i) {
                      final p = ctrl.products[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: p.image.isNotEmpty
                              ? Image.network(
                                  p.image,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(p.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.description.replaceAll(
                                  RegExp(r'<[^>]*>'),
                                  '',
                                ),
                              ), // Strips HTML
                              Text('${p.mpc}  |  ${p.mpcJednokratno}'),
                              Text('EAN: ${p.ean} | Brand: ${p.brand}'),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: Icon(Icons.print),
                            onPressed: () {
                              showPriceTagOptionDialog(context, (
                                withDescription,
                              ) async {
                                final logoBytes =
                                    await PriceTagPrinter.loadLogoBytes();
                                // Call your print function here, pass withDescription as bool
                                PriceTagPrinter.printPriceTag(
                                  name: p.name,
                                  price: p.mpc,
                                  ean: p.ean,
                                  logoBytes: logoBytes,
                                  brand: p.brand,
                                  description: p.description,
                                  withDescription: withDescription,
                                );
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
