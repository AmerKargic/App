import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:barcode/barcode.dart';
import 'package:image/image.dart' as im;
import 'package:barcode_image/barcode_image.dart';
import 'package:image/image.dart';
import 'package:image/image.dart' as barcodeImg show fill;

class PriceTagPrinter {
  static final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  static Future<BluetoothDevice?> selectAndConnectPrinter() async {
    List<BluetoothDevice> devices = await _bluetooth.getBondedDevices();
    if (devices.isEmpty) return null;
    bool connected = await _bluetooth.isConnected ?? false;
    if (!connected) {
      await _bluetooth.connect(devices.first);
    }
    return devices.first;
  }

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

  static Future<void> printPriceTag({
    required String name,
    required String brand,
    required String price,
    required String ean,
    required Uint8List logoBytes,
    required String description,
    required bool withDescription,
  }) async {
    // Print logo (centered)

    await _bluetooth.printImageBytes(logoBytes);

    await _bluetooth.printNewLine();

    // Print product name (big, centered)
    await _bluetooth.printCustom(name, 3, 1); // 3 = biggest font, 1 = centered

    // Print brand (medium, centered)
    await _bluetooth.printCustom(brand, 1, 1); // 1 = medium font, 1 = centered
    if (withDescription) {
      // Print description (normal, left-aligned)
      await _bluetooth.printCustom(
        description,
        0,
        0,
      ); // 0 = normal font, 0 = left-aligned
    }
    await _bluetooth.printNewLine();

    // Print price (very big, centered)
    await _bluetooth.printCustom('€$price', 3, 1);

    await _bluetooth.printNewLine();

    // Generate barcode image (Code128)
    final barcode = Barcode.code128();
    final barcodeImg = im.Image(width: 340, height: 90);
    im.fill(barcodeImg, color: im.ColorUint8.rgb(255, 255, 255));

    drawBarcode(barcodeImg, barcode, ean);

    // Make sure it's black & white

    final barcodeBytes = Uint8List.fromList(im.encodePng(barcodeImg));

    // Convert to PNG

    // Print the barcode image (centered)
    await _bluetooth.printImageBytes(barcodeBytes);

    // Print EAN below barcode (centered)
    await _bluetooth.printCustom(ean, 1, 1);

    await _bluetooth.printNewLine();
    await _bluetooth.printNewLine();
    await _bluetooth.printNewLine();
    await _bluetooth.printNewLine();
    await _bluetooth.printNewLine();
  }

  static Future<Uint8List> loadLogoBytes() async {
    ByteData bytes = await rootBundle.load('assets/images/logo.png');
    return bytes.buffer.asUint8List();
  }
}
