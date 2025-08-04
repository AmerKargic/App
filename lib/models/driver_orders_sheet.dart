import 'package:flutter/material.dart';
import 'package:digitalisapp/models/driver_order_model.dart';

class DriverOrdersSheet extends StatelessWidget {
  final List<DriverOrder> orders;

  const DriverOrdersSheet({Key? key, required this.orders}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Orders',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ListTile(
                    title: Text('Order ID: ${order.oid}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${order.kupac.naziv}'),
                        Text('Address: ${order.kupac.adresa}'),
                        Text('Total Amount: ${order.iznos.toStringAsFixed(2)}'),
                        Text('Boxes: ${order.brojKutija}'),
                      ],
                    ),
                    onTap: () {
                      // Show order details in a dialog
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text('Order Details (ID: ${order.oid})'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer: ${order.kupac.naziv}'),
                                Text('Address: ${order.kupac.adresa}'),
                                Text('Phone: ${order.kupac.telefon}'),
                                Text('Email: ${order.kupac.email}'),
                                const SizedBox(height: 16),
                                const Text(
                                  'Items:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                ...order.stavke.map(
                                  (item) => Text(
                                    '${item.naziv} (EAN: ${item.ean}) - ${item.kol} pcs @ ${item.mpc.toStringAsFixed(2)}',
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
