import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart' as qr;
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';

class LeafletGenerator {
  Future<Uint8List> generateLeaflet({
    required String brand,
    required String model,
    required String processor,
    required String ram,
    required String ssd,
    required String gpu,
    required String os,
    required String warranty,
    required String diagonal,
    required String resolution,
    required String ean,
    required String productId,
    required String productName,
    required List<String> descriptionBullets,
    required Uint8List brandLogo,
    required Uint8List intelSticker,
    required Uint8List nvidiaSticker,
    Uint8List? amdSticker,
    Uint8List? ryzenSticker,
    required Uint8List osIcon,
    required Uint8List iconCpu,
    required Uint8List iconRam,
    required Uint8List iconSsd,
    required Uint8List iconGpu,
    required Uint8List iconOs,
    required Uint8List iconWarranty,
    required Uint8List iconLaptop,
    required pw.Font customFont,
  }) async {
    final pdf = pw.Document();

    // QR kod (pretvoren u sliku)
    final qrValidationResult = qr.QrValidator.validate(
      data: "https://www.digitalis.ba/$productId/$productName",
      version: qr.QrVersions.auto,
      errorCorrectionLevel: qr.QrErrorCorrectLevel.Q,
    );
    final qrCode = qrValidationResult.qrCode;
    final painter = qr.QrPainter.withQr(qr: qrCode!, gapless: true);
    final qrImageData = await painter.toImageData(300);
    final qrImage = pw.MemoryImage(qrImageData!.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ==== Lijevi blok: slika laptopa + brand + model + specs ====
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Slika laptopa sa dijagonalom centriranom preko slike
                    pw.Stack(
                      alignment: pw.Alignment.center,
                      children: [
                        pw.Image(
                          pw.MemoryImage(iconLaptop),
                          width: 200,
                          height: 150,
                        ),
                        if (diagonal.isNotEmpty)
                          pw.Container(
                            width: 200,
                            height: 150,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              _extractInches(diagonal),
                              style: pw.TextStyle(
                                font: customFont,
                                fontSize: 32,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                                background: pw.BoxDecoration(
                                  color: PdfColors.black,
                                ),
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                    pw.SizedBox(height: 24),
                    // Brand logo (iz baze ili placeholder)
                    // pw.Image(pw.MemoryImage(brandLogo), height: 50),
                    pw.SizedBox(height: 18),
                    // Brand ime
                    pw.Text(
                      brand,
                      style: pw.TextStyle(
                        font: customFont,
                        fontSize: 32,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    // Model
                    pw.Text(
                      "Model: $model",
                      style: pw.TextStyle(font: customFont, fontSize: 22),
                    ),
                    pw.SizedBox(height: 24),
                    // Specifikacije sa ikonama
                    _buildSpecRow(iconCpu, processor, customFont),
                    _buildSpecRow(iconRam, ram, customFont),
                    _buildSpecRow(iconSsd, ssd, customFont),
                    _buildSpecRow(iconGpu, gpu, customFont),
                    _buildSpecRow(iconOs, os, customFont),
                    _buildSpecRow(iconWarranty, warranty, customFont),
                  ],
                ),
                pw.Spacer(),
                // ==== Desni blok: stickers gore + opis + QR dole ====
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Stickers (samo CPU i GPU stickeri)
                    pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Image(pw.MemoryImage(intelSticker), height: 50),
                        if (nvidiaSticker != null) ...[
                          pw.SizedBox(width: 12),
                          pw.Image(pw.MemoryImage(nvidiaSticker), height: 50),
                        ],
                      ],
                    ),
                    pw.Spacer(),
                    // Bullet lista
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: descriptionBullets
                          .where((b) => b.trim().isNotEmpty)
                          .map(
                            (b) => pw.Bullet(
                              text: b,
                              style: pw.TextStyle(
                                font: customFont,
                                fontSize: 16,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    pw.Spacer(),
                    // QR kod + EAN
                    pw.Column(
                      children: [
                        pw.Text(
                          "Skeniraj QR kod za više informacija",
                          style: pw.TextStyle(font: customFont, fontSize: 12),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Image(qrImage, height: 80, width: 80),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          "EAN: $ean",
                          style: pw.TextStyle(font: customFont, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSpecRow(
    Uint8List iconBytes,
    String value,
    pw.Font customFont,
  ) {
    if (value.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Container(
            width: 22,
            height: 22,
            child: pw.Image(pw.MemoryImage(iconBytes)),
          ),
          pw.SizedBox(width: 12),
          pw.Text(value, style: pw.TextStyle(font: customFont, fontSize: 18)),
        ],
      ),
    );
  }

  static String _extractInches(String input) {
    final match = RegExp(r'(\d{2}\.?\d*)').firstMatch(input);
    return match != null ? '${match.group(1)}"' : input;
  }
}

// ================== POZIV SA SCREENA ==================

Future<void> generateLeafletForEan(BuildContext context, String ean) async {
  final session = await SessionManager().getUser();
  if (session == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Nema aktivne sesije!')));
    return;
  }

  final product = await ApiService().getProductByBarcode(
    ean,
    int.parse(session['kup_id'].toString()),
    int.parse(session['pos_id'].toString()),
    session['hash1'],
    session['hash2'],
  );

  if (product['success'] != 1) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Greška: ${product['message']}')));
    print('API odgovor: $product');
    return;
  }

  final data = product['data'];
  final opis = data['description'] as String? ?? '';
  final liRegExp = RegExp(r'<li>(.*?)<\/li>', caseSensitive: false);
  final parts = liRegExp
      .allMatches(opis)
      .map((m) => m.group(1)?.trim() ?? '')
      .toList();

  final diagonal = parts.length > 0 ? parts[0] : '';
  final processor = parts.length > 1 ? parts[1] : '';
  final gpu = parts.length > 2 ? parts[2] : '';
  final ramSsd = parts.length > 3 ? parts[3] : '';
  final warranty = parts.length > 4 ? parts[4] : '';
  String ram = '', ssd = '';
  if (ramSsd.contains('SSD')) {
    final ramSsdParts = ramSsd.split('i');
    ram = ramSsdParts[0].trim();
    ssd = ramSsdParts.length > 1 ? 'i${ramSsdParts[1]}' : '';
  }
  final descriptionBullets = parts.length > 5 ? parts.sublist(5) : [];

  Uint8List brandLogo;
  if (data['brand_logo'] != null && data['brand_logo'].toString().isNotEmpty) {
    brandLogo = base64Decode(data['brand_logo']);
  } else {
    final logoAsset = await rootBundle.load('assets/stickers/icon_cpu.png');
    brandLogo = logoAsset.buffer.asUint8List();
  }
  final intelSticker = await rootBundle.load('assets/stickers/intelcore.png');
  final nvidiaSticker = await rootBundle.load('assets/stickers/rtx.png');
  final amdSticker = await rootBundle.load('assets/stickers/radeon.png');
  final ryzenSticker = await rootBundle.load('assets/stickers/ryzen.png');
  final osIcon = await rootBundle.load('assets/stickers/icon_os.png');
  final iconCpu = await rootBundle.load('assets/stickers/icon_cpu.png');
  final iconRam = await rootBundle.load('assets/stickers/icon_ram.png');
  final iconSsd = await rootBundle.load('assets/stickers/icon_ssd.png');
  final iconGpu = await rootBundle.load('assets/stickers/icon_gpu.png');
  final iconWarranty = await rootBundle.load(
    'assets/stickers/icon_warranty.png',
  );
  final iconLaptop = await rootBundle.load('assets/stickers/icon_laptop.png');

  // Dinamički biraj sticker za CPU
  Uint8List cpuSticker = intelSticker.buffer.asUint8List();
  if (processor.toLowerCase().contains('intel')) {
    cpuSticker = intelSticker.buffer.asUint8List();
  } else if (processor.toLowerCase().contains('ryzen')) {
    cpuSticker = ryzenSticker.buffer.asUint8List();
  } else if (processor.toLowerCase().contains('amd')) {
    cpuSticker = amdSticker.buffer.asUint8List();
  }

  // Dinamički biraj sticker za GPU
  Uint8List gpuSticker = nvidiaSticker.buffer.asUint8List();
  if (gpu.toLowerCase().contains('nvidia') ||
      gpu.toLowerCase().contains('rtx')) {
    gpuSticker = nvidiaSticker.buffer.asUint8List();
  } else if (gpu.toLowerCase().contains('amd') ||
      gpu.toLowerCase().contains('radeon')) {
    gpuSticker = amdSticker.buffer.asUint8List();
  }

  // Učitaj custom font
  final fontData = await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
  final customFont = pw.Font.ttf(fontData);

  final pdfBytes = await LeafletGenerator().generateLeaflet(
    brand: data['Brand'] ?? '',
    model: data['model'] ?? '',
    processor: processor,
    ram: ram,
    ssd: ssd,
    gpu: gpu,
    os: '', // možeš dodati ako imaš OS info
    warranty: warranty,
    diagonal: diagonal,
    resolution: '', // možeš dodati ako imaš rezoluciju
    ean: data['EAN'] ?? '',
    productId: data['ID'].toString(),
    productName: data['name'] ?? '',
    descriptionBullets: descriptionBullets.cast<String>(),
    brandLogo: brandLogo,
    intelSticker: cpuSticker,
    nvidiaSticker: gpuSticker,
    amdSticker: amdSticker.buffer.asUint8List(),
    ryzenSticker: ryzenSticker.buffer.asUint8List(),
    osIcon: osIcon.buffer.asUint8List(),
    iconCpu: iconCpu.buffer.asUint8List(),
    iconRam: iconRam.buffer.asUint8List(),
    iconSsd: iconSsd.buffer.asUint8List(),
    iconGpu: iconGpu.buffer.asUint8List(),
    iconOs: osIcon.buffer.asUint8List(),
    iconWarranty: iconWarranty.buffer.asUint8List(),
    iconLaptop: iconLaptop.buffer.asUint8List(),
    customFont: customFont,
  );

  await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
}
