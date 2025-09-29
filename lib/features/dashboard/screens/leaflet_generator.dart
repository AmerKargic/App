import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:digitalisapp/services/api_service.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';

enum LeafletType { laptop, tv, white }

class LeafletGenerator {
  final LeafletType type;
  LeafletGenerator({this.type = LeafletType.laptop});

  Future<void> addLeafletPage({
    required pw.Document pdf,
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
    required String series,

    required Uint8List brandLogo,
    required bool isSmart,
    required String audioPower,
    required List<Map<String, dynamic>> specs,

    // LAPTOP
    Uint8List? cpuSticker,
    Uint8List? gpuSticker,
    Uint8List? osIcon,
    Uint8List? iconCpu,
    Uint8List? iconRam,
    Uint8List? iconSsd,
    Uint8List? iconGpu,
    Uint8List? iconOs,
    Uint8List? iconWarranty,
    Uint8List? iconLaptop,
    // TV
    Uint8List? iconTv,
    Uint8List? iconSize,
    Uint8List? iconPanel,
    Uint8List? iconSmart,
    Uint8List? iconPorts,
    Uint8List? iconAudio,
    Uint8List? iconResolution,
    Uint8List? osLogo,
    Uint8List? resLogo,
    required pw.Font customFont,
  }) async {
    final ime = productName.replaceAll(' ', '');

    pw.Widget leftBlock = pw.SizedBox();
    pw.Widget rightBlock = pw.SizedBox();

    switch (type) {
      case LeafletType.laptop:
        leftBlock = pw.Container(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Stack(
                alignment: pw.Alignment.center,
                children: [
                  pw.Image(
                    pw.MemoryImage(iconLaptop!),
                    width: 220,
                    height: 170,
                  ),
                  pw.Container(
                    width: 220,
                    height: 170,
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          resolution,
                          style: pw.TextStyle(
                            font: customFont,
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        if (diagonal.isNotEmpty)
                          pw.Text(
                            _extractInches(diagonal),
                            style: pw.TextStyle(
                              font: customFont,
                              fontSize: 28,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              if (brandLogo.isNotEmpty)
                pw.Image(pw.MemoryImage(brandLogo), height: 50)
              else
                pw.Text(
                  brand,
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.Text(
                "Model: $model",
                style: pw.TextStyle(font: customFont, fontSize: 22),
                maxLines: 1,
                overflow: pw.TextOverflow.visible,
              ),
              pw.SizedBox(height: 24),

              _buildSpecRow(iconCpu!, processor, customFont),
              _buildSpecRow(iconRam!, ram, customFont),
              _buildSpecRow(iconSsd!, ssd, customFont),
              _buildSpecRow(iconGpu!, gpu, customFont),
              _buildSpecRow(iconOs!, os, customFont),

              _buildSpecRow(iconWarranty!, warranty, customFont),
            ],
          ),
        );
        rightBlock = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Image(pw.MemoryImage(cpuSticker!), height: 80),
                if (gpuSticker != null && gpuSticker.isNotEmpty) ...[
                  pw.SizedBox(width: 12),
                  pw.Image(pw.MemoryImage(gpuSticker), height: 80),
                ],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.SizedBox(height: 32),
            pw.Column(
              children: [
                pw.SizedBox(height: 200),
                pw.Text(
                  "Skeniraj QR kod za više informacija",
                  style: pw.TextStyle(font: customFont, fontSize: 12),
                ),
                pw.SizedBox(height: 12),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: "https://www.dstore.ba/$productId/$ime",
                  width: 100,
                  height: 100,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  "EAN: $ean",
                  style: pw.TextStyle(font: customFont, fontSize: 12),
                ),
              ],
            ),
          ],
        );
        break;

      case LeafletType.tv:
        leftBlock = pw.Container(
          width: 250,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Stack(
                children: [
                  pw.Image(pw.MemoryImage(iconTv!), width: 220, height: 170),
                  // Inči u gornjem desnom uglu
                  pw.Positioned(
                    right: 25,
                    top: 40,
                    child: pw.Text(
                      _extractInches(diagonal),
                      style: pw.TextStyle(
                        font: customFont,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                  // Centimetri u donjem lijevom uglu
                  pw.Positioned(
                    left: 25,
                    bottom: 60,
                    child: pw.Text(
                      _extractCm(diagonal),
                      style: pw.TextStyle(
                        font: customFont,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              if (brandLogo.isNotEmpty)
                pw.Image(pw.MemoryImage(brandLogo), height: 50)
              else
                pw.Text(
                  brand,
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              pw.Text(
                "Model: $model",
                style: pw.TextStyle(font: customFont, fontSize: 22),
                maxLines: 1,
                overflow: pw.TextOverflow.visible,
              ),
              if (series.isNotEmpty)
                pw.Text(
                  "Serija: $series",
                  style: pw.TextStyle(font: customFont, fontSize: 18),
                  maxLines: 1,
                  overflow: pw.TextOverflow.visible,
                ),
              pw.SizedBox(height: 24),
              _buildSpecRow(
                iconSize!,
                'Ekran veličina: ${_extractInches(diagonal)} / ${_extractCm(diagonal)}',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconPanel!,
                'Panel: $resolution',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconSmart!,
                'Smart: ${isSmart ? "Da" : "Ne"}',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconAudio!,
                'Audio: $audioPower',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconPorts!,
                'Konektori: HDMI x3, USB x1, CI+, Satelitski, LAN RJ-45',
                customFont,
                fontSize: 14,
              ),

              _buildSpecRow(
                iconOs!,
                'Operativni sistem: $os',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconWarranty!,
                'Garancija: $warranty',
                customFont,
                fontSize: 14,
              ),
            ],
          ),
        );
        rightBlock = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Image(pw.MemoryImage(osLogo!), height: 80),
                pw.SizedBox(width: 12),
                pw.Image(pw.MemoryImage(resLogo!), height: 80),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              margin: const pw.EdgeInsets.only(right: 12, bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    "Skeniraj QR kod za više informacija",
                    style: pw.TextStyle(font: customFont, fontSize: 12),
                  ),
                  pw.SizedBox(height: 6),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: "https://www.dstore.ba/$productId/$ime",
                    width: 100,
                    height: 100,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    "EAN: $ean",
                    style: pw.TextStyle(font: customFont, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
        break;

      case LeafletType.white:
        // Dodaj layout za white goods po potrebi
        leftBlock = pw.Container(
          width: 250,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                brand,
                style: pw.TextStyle(
                  font: customFont,
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                "Model: $model",
                style: pw.TextStyle(font: customFont, fontSize: 22),
              ),
              pw.SizedBox(height: 24),
              _buildSpecRow(iconSsd!, ssd, customFont),
              _buildSpecRow(iconWarranty!, warranty, customFont),
            ],
          ),
        );
        rightBlock = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              "Skeniraj QR kod za više informacija",
              style: pw.TextStyle(font: customFont, fontSize: 12),
            ),
            pw.SizedBox(height: 6),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: "https://www.dstore.ba/$productId/$ime",
              width: 100,
              height: 100,
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              "EAN: $ean",
              style: pw.TextStyle(font: customFont, fontSize: 12),
            ),
          ],
        );
        break;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(0),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: leftBlock),
                pw.SizedBox(width: 40),
                pw.Expanded(child: rightBlock),
              ],
            ),
          );
        },
      ),
    );
  }

  pw.Widget _buildSpecRow(
    Uint8List iconBytes,
    String value,
    pw.Font customFont, {
    double fontSize = 18,
  }) {
    if (value.isEmpty || iconBytes.isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Container(
            width: 22,
            height: 22,
            child: pw.Image(pw.MemoryImage(iconBytes)),
          ),
          pw.SizedBox(width: 12),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: customFont,
              fontSize: fontSize,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static String _extractInches(String input) {
    final match = RegExp(r'(\d{2}\.?\d*)').firstMatch(input);
    return match != null ? '${match.group(1)}"' : input;
  }

  static String _extractCm(String input) {
    final match = RegExp(r'(\d{2,3})\s*cm').firstMatch(input.toLowerCase());
    return match != null ? '${match.group(1)}cm' : '';
  }
}

// ================== POZIV ZA VIŠE EAN-OVA ==================
Future<void> generateLeafletsForEans(
  BuildContext context,
  List<String> eans,
  // 'laptop', 'tv', 'white'
) async {
  final session = await SessionManager().getUser();
  if (session == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Nema aktivne sesije!')));
    return;
  }

  final pdf = pw.Document();

  for (final ean in eans) {
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
      continue;
    }
    print('API odgovor: $product');

    final data = product['data'];
    final specs = (data['specs'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final parts = specs
        .map((spec) => '${spec['name']}: ${spec['value']}'.toString())
        .where((e) => e.isNotEmpty)
        .toList();
    print('Specs dijelovi: $parts');
    bool isSmart = false;
    final nameLower = (data['name'] ?? '').toString().toLowerCase();
    if (nameLower.contains('smart')) {
      isSmart = true;
    } else {
      for (final part in parts) {
        if (part.toLowerCase().contains('smart')) {
          isSmart = true;
          break;
        }
      }
    }

    // === AUDIO SNAGA ===
    String audioPower = '';
    for (final part in parts) {
      final lower = part.toLowerCase();
      final match = RegExp(
        r'(\d{2,3})\s*w',
        caseSensitive: false,
      ).firstMatch(lower);
      if (match != null) {
        audioPower = 'Audio: ${match.group(1)}W';
        break;
      }
      // fallback: traži "audio" + broj
      final audioMatch = RegExp(
        r'audio.*?(\d{2,3})\s*w',
        caseSensitive: false,
      ).firstMatch(lower);
      if (audioMatch != null) {
        audioPower = 'Audio: ${audioMatch.group(1)}W';
        break;
      }
    }
    if (audioPower.isEmpty) {
      audioPower = 'Audio: --';
    }
    String diagonal = '';
    String processor = '';
    String gpu = '';
    String ram = '';
    String ssd = '';
    String warranty = '';
    String os = '';
    String resolution = '';
    String series = data['Serija']?.toString() ?? '';

    for (final part in parts) {
      final lower = part.toLowerCase().trim();
      final lowerNoDot = lower.endsWith(':')
          ? lower.substring(0, lower.length - 1)
          : lower;

      if (RegExp(r'(\d+(\.\d+)?("| inch|inča))').hasMatch(lowerNoDot)) {
        diagonal = part;
      } else if (lowerNoDot.contains('procesor') ||
          lowerNoDot.contains('intel i') ||
          lowerNoDot.contains('i3') ||
          lowerNoDot.contains('i5') ||
          lowerNoDot.contains('i7') ||
          lowerNoDot.contains('i9') ||
          lowerNoDot.contains('celeron') ||
          lowerNoDot.contains('ryzen')) {
        processor = part;
      } else if (lowerNoDot.contains('graf') ||
          lowerNoDot.contains('grafička') ||
          lowerNoDot.contains('nvidia') ||
          lowerNoDot.contains('radeon') ||
          lowerNoDot.contains('uhd') ||
          lowerNoDot.contains('amd') ||
          lowerNoDot.contains('integrisana') ||
          lowerNoDot.contains('geforce')) {
        gpu = part;
      } else if (ram.isEmpty &&
          (lowerNoDot.contains('ram') ||
              lowerNoDot.contains('memorija') ||
              lowerNoDot.contains('ddr4') ||
              lowerNoDot.contains('ddr5') ||
              RegExp(r'\b\d+\s*gb\b').hasMatch(lowerNoDot))) {
        ram = part;
      } else if (RegExp(
        r'(ssd|hdd|\d+\s*gb.*ssd|\d+\s*tb.*ssd)',
      ).hasMatch(lowerNoDot)) {
        ssd = part;
      } else if (lowerNoDot.contains('garanc')) {
        warranty = part;
      } else if (lowerNoDot.contains('fhd') ||
          lowerNoDot.contains('hd') ||
          lowerNoDot.contains('4k') ||
          lowerNoDot.contains('uhd') ||
          lowerNoDot.contains('fullhd') ||
          lowerNoDot.contains('full hd') ||
          lowerNoDot.contains('retina') ||
          lowerNoDot.contains('3840x2160') ||
          lowerNoDot.contains('1920x1080') ||
          lowerNoDot.contains('1366x768') ||
          lowerNoDot.contains('2560x1440') ||
          lowerNoDot.contains('3200x1800')) {
        resolution = part;
      }
    }
    for (final part in parts) {
      final lower = part.toLowerCase().trim();
      final lowerNoDot = lower.endsWith(':')
          ? lower.substring(0, lower.length - 1)
          : lower;

      if (os.isEmpty &&
          (lowerNoDot.contains('operativni sistem') ||
              lowerNoDot.contains('os') ||
              lowerNoDot.contains('windows') ||
              lowerNoDot.contains('linux') ||
              lowerNoDot.contains('freedos') ||
              lowerNoDot.contains('dos') ||
              lowerNoDot.contains('webos') ||
              lowerNoDot.contains('android'))) {
        os = part;
      }
    }
    // LOGO
    Uint8List? brandLogo;
    if (data['logo_url'] != null && data['logo_url'].toString().isNotEmpty) {
      final logoResponse = await http.get(Uri.parse(data['logo_url']));
      if (logoResponse.statusCode == 200) {
        brandLogo = logoResponse.bodyBytes;
      }
    }

    // Ikone za TV
    final iconTv = await rootBundle.load('assets/stickers/icon_tv.png');
    final iconSize = await rootBundle.load('assets/stickers/icon_tv.png');
    final iconPanel = await rootBundle.load('assets/stickers/icon_panel.png');
    final iconSmart = await rootBundle.load('assets/stickers/icon_smart.png');
    final iconPorts = await rootBundle.load('assets/stickers/icon_ports.png');
    final iconAudio = await rootBundle.load('assets/stickers/icon_audio.png');
    final iconOs = await rootBundle.load('assets/stickers/icon_os.png');
    final iconWarranty = await rootBundle.load(
      'assets/stickers/icon_warranty.png',
    );
    final iconResolution = await rootBundle.load(
      'assets/stickers/icon_panel.png',
    );

    // OS logo
    Uint8List osLogo;
    if (os.toLowerCase().contains('tizen')) {
      osLogo = (await rootBundle.load(
        'assets/stickers/icon_tizen.png',
      )).buffer.asUint8List();
    } else if (os.toLowerCase().contains('webos')) {
      osLogo = (await rootBundle.load(
        'assets/stickers/icon_webos.png',
      )).buffer.asUint8List();
    } else if (os.toLowerCase().contains('android')) {
      osLogo = (await rootBundle.load(
        'assets/stickers/icon_tizen.png',
      )).buffer.asUint8List();
    } else {
      osLogo = (await rootBundle.load(
        'assets/stickers/icon_os.png',
      )).buffer.asUint8List();
    }

    // Rezolucija logo
    Uint8List resLogo;
    if (resolution.toLowerCase().contains('4k')) {
      resLogo = (await rootBundle.load(
        'assets/stickers/logo_4k.png',
      )).buffer.asUint8List();
    } else if (resolution.toLowerCase().contains('uhd')) {
      resLogo = (await rootBundle.load(
        'assets/stickers/logo_4k.png',
      )).buffer.asUint8List();
    } else if (resolution.toLowerCase().contains('fhd')) {
      resLogo = (await rootBundle.load(
        'assets/stickers/logo_4k.png',
      )).buffer.asUint8List();
    } else {
      resLogo = (await rootBundle.load(
        'assets/stickers/logo_4k.png',
      )).buffer.asUint8List();
    }

    // Ikone za laptop
    final intelGpuSticker = await rootBundle.load(
      'assets/stickers/intelgpu.png',
    );
    final intelSticker = await rootBundle.load('assets/stickers/intelcore.png');
    final nvidiaSticker = await rootBundle.load('assets/stickers/rtx.png');
    final amdSticker = await rootBundle.load('assets/stickers/radeon.png');
    final ryzenSticker = await rootBundle.load('assets/stickers/ryzen.png');
    final osIcon = await rootBundle.load('assets/stickers/icon_os.png');
    final iconCpu = await rootBundle.load('assets/stickers/icon_cpu.png');
    final iconRam = await rootBundle.load('assets/stickers/icon_ram.png');
    final iconSsd = await rootBundle.load('assets/stickers/icon_ssd.png');
    final iconGpu = await rootBundle.load('assets/stickers/icon_gpu.png');
    final iconWarrantyLap = await rootBundle.load(
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

    // GPU sticker
    final gpuLower = gpu.toLowerCase();
    Uint8List gpuSticker = nvidiaSticker.buffer.asUint8List();
    if (gpuLower.contains('intel uhd')) {
      gpuSticker = intelGpuSticker.buffer.asUint8List();
    } else if (gpuLower.contains('nvidia') || gpuLower.contains('rtx')) {
      gpuSticker = nvidiaSticker.buffer.asUint8List();
    } else if (gpuLower.contains('amd') || gpuLower.contains('radeon')) {
      gpuSticker = amdSticker.buffer.asUint8List();
    }

    final fontData = await rootBundle.load(
      'assets/fonts/Montserrat-Regular.ttf',
    );
    final customFont = pw.Font.ttf(fontData);

    // ...prepoznavanje tipa...
    String leafletType = 'white';
    if (data['Podkategorija'] != null) {
      final podkategorija = data['Podkategorija'].toString().toLowerCase();
      if (podkategorija.contains('tv'))
        leafletType = 'tv';
      else if (podkategorija.contains('laptop'))
        leafletType = 'laptop';
    } else if (data['name'] != null) {
      final name = data['name'].toString().toLowerCase();
      if (name.contains('tv'))
        leafletType = 'tv';
      else if (name.contains('laptop'))
        leafletType = 'laptop';
    }

    final leafletGen = leafletType == 'tv'
        ? LeafletGenerator(type: LeafletType.tv)
        : leafletType == 'laptop'
        ? LeafletGenerator(type: LeafletType.laptop)
        : LeafletGenerator(type: LeafletType.white);
    print('OS: $os');
    print('iconOs length: ${iconOs.buffer.asUint8List().length}');
    await leafletGen.addLeafletPage(
      specs: specs,
      pdf: pdf,
      brand: data['Brand'] ?? '',
      model: data['Model'] ?? '',
      processor: processor,
      ram: ram,
      ssd: ssd,
      gpu: gpu,
      os: os,
      warranty: warranty,
      diagonal: diagonal,
      resolution: resolution,
      ean: data['EAN'] ?? '',
      productId: data['ID'].toString(),
      productName: data['name'] ?? '',
      series: series,

      brandLogo: brandLogo ?? Uint8List(0),
      // LAPTOP
      cpuSticker: cpuSticker,
      gpuSticker: gpuSticker,
      osIcon: osIcon.buffer.asUint8List(),
      iconCpu: iconCpu.buffer.asUint8List(),
      iconRam: iconRam.buffer.asUint8List(),
      iconSsd: iconSsd.buffer.asUint8List(),
      iconGpu: iconGpu.buffer.asUint8List(),
      iconOs: osIcon.buffer.asUint8List(),
      iconWarranty: iconWarrantyLap.buffer.asUint8List(),
      iconLaptop: iconLaptop.buffer.asUint8List(),
      // TV
      isSmart: isSmart,
      audioPower: audioPower,
      iconTv: iconTv.buffer.asUint8List(),
      iconSize: iconSize.buffer.asUint8List(),
      iconPanel: iconPanel.buffer.asUint8List(),
      iconSmart: iconSmart.buffer.asUint8List(),
      iconPorts: iconPorts.buffer.asUint8List(),
      iconAudio: iconAudio.buffer.asUint8List(),
      iconResolution: iconResolution.buffer.asUint8List(),
      osLogo: osLogo,
      resLogo: resLogo,
      customFont: customFont,
    );
  }

  await Printing.layoutPdf(onLayout: (_) async => pdf.save());
}
