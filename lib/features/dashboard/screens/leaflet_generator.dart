// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:qr_flutter/qr_flutter.dart' as qr;
// import 'package:flutter/material.dart';
// import 'package:digitalisapp/services/api_service.dart';
// import 'package:digitalisapp/core/utils/session_manager.dart';

// class LeafletGenerator {
//   Future<Uint8List> generateLeaflet({
//     required String brand,
//     required String model,
//     required String processor,
//     required String ram,
//     required String ssd,
//     required String gpu,
//     required String os,
//     required String warranty,
//     required String diagonal,
//     required String resolution,
//     required String ean,
//     required String productId,
//     required String productName,
//     required List<String> descriptionBullets,
//     required Uint8List brandLogo,
//     required Uint8List cpuSticker,
//     required Uint8List gpuSticker,
//     Uint8List? amdSticker,
//     Uint8List? ryzenSticker,
//     required Uint8List osIcon,
//     required Uint8List iconCpu,
//     required Uint8List iconRam,
//     required Uint8List iconSsd,
//     required Uint8List iconGpu,
//     required Uint8List iconOs,
//     required Uint8List iconWarranty,
//     required Uint8List iconLaptop,
//     required pw.Font customFont,
//   }) async {
//     final pdf = pw.Document();
//     final ime = productName.replaceAll(' ', '');
//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat.a4.landscape,
//         build: (context) {
//           return pw.Padding(
//             padding: const pw.EdgeInsets.all(24),
//             child: pw.Row(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 // ==== Lijevi blok sa fiksnom širinom ====
//                 pw.Container(
//                   width: 250, // 🔑 fiksna širina sprječava unbounded width
//                   child: pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.start,
//                     children: [
//                       pw.Stack(
//                         alignment: pw.Alignment.center,
//                         children: [
//                           pw.Image(
//                             pw.MemoryImage(iconLaptop),
//                             width: 220,
//                             height: 170,
//                           ),

//                           pw.Container(
//                             width: 220,
//                             height: 170,
//                             alignment: pw.Alignment.center,
//                             child: pw.Column(
//                               mainAxisSize: pw.MainAxisSize.min,
//                               children: [
//                                 pw.Text(
//                                   resolution,
//                                   style: pw.TextStyle(
//                                     font: customFont,
//                                     fontSize: 14,
//                                     fontWeight: pw.FontWeight.bold,
//                                     color: PdfColors.black,
//                                   ),
//                                   textAlign: pw.TextAlign.center,
//                                 ),
//                                 if (diagonal.isNotEmpty)
//                                   pw.Text(
//                                     _extractInches(diagonal),
//                                     style: pw.TextStyle(
//                                       font: customFont,
//                                       fontSize: 28,
//                                       fontWeight: pw.FontWeight.bold,
//                                       color: PdfColors.black,
//                                     ),
//                                     textAlign: pw.TextAlign.center,
//                                   ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),

//                       pw.SizedBox(height: 24),
//                       if (brandLogo != null)
//                         pw.Image(pw.MemoryImage(brandLogo), height: 50)
//                       else
//                         pw.Text(
//                           brand,
//                           style: pw.TextStyle(
//                             font: customFont,
//                             fontSize: 32,
//                             fontWeight: pw.FontWeight.bold,
//                           ),
//                         ),
//                       pw.Text(
//                         "Model: $model",
//                         style: pw.TextStyle(font: customFont, fontSize: 22),
//                       ),
//                       pw.SizedBox(height: 24),
//                       _buildSpecRow(iconCpu, processor, customFont),
//                       _buildSpecRow(iconRam, ram, customFont),
//                       _buildSpecRow(iconSsd, ssd, customFont),
//                       _buildSpecRow(iconGpu, gpu, customFont),
//                       _buildSpecRow(iconOs, os, customFont),
//                       _buildSpecRow(iconWarranty, warranty, customFont),
//                     ],
//                   ),
//                 ),

//                 pw.SizedBox(width: 40),

//                 // ==== Desni blok zauzima ostatak prostora ====
//                 pw.Expanded(
//                   child: pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.end,
//                     children: [
//                       pw.Row(
//                         mainAxisSize: pw.MainAxisSize.min,
//                         children: [
//                           pw.Image(pw.MemoryImage(cpuSticker), height: 80),
//                           if (gpuSticker != null) ...[
//                             pw.SizedBox(width: 12),
//                             pw.Image(pw.MemoryImage(gpuSticker), height: 80),
//                           ],
//                         ],
//                       ),
//                       pw.SizedBox(height: 20),
//                       // pw.Column(
//                       //   crossAxisAlignment: pw.CrossAxisAlignment.start,
//                       //   children: descriptionBullets
//                       //       .where((b) => b.trim().isNotEmpty)
//                       //       .map(
//                       //         (b) => pw.Bullet(
//                       //           text: b,
//                       //           style: pw.TextStyle(
//                       //             font: customFont,
//                       //             fontSize: 16,
//                       //           ),
//                       //         ),
//                       //       )
//                       //       .toList(),
//                       // ),
//                       pw.SizedBox(height: 180),
//                       pw.Column(
//                         children: [
//                           pw.Text(
//                             "Skeniraj QR kod za više informacija",
//                             style: pw.TextStyle(font: customFont, fontSize: 12),
//                           ),
//                           pw.SizedBox(height: 6),

//                           pw.BarcodeWidget(
//                             barcode: pw.Barcode.qrCode(),

//                             data: "https://www.dstore.ba/$productId/$ime",
//                             width: 100,
//                             height: 100,
//                           ),
//                           pw.SizedBox(height: 6),
//                           pw.Text(
//                             "EAN: $ean",
//                             style: pw.TextStyle(font: customFont, fontSize: 12),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );

//     return pdf.save();
//   }

//   pw.Widget _buildSpecRow(
//     Uint8List iconBytes,
//     String value,
//     pw.Font customFont,
//   ) {
//     if (value.isEmpty) return pw.SizedBox();
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 4),
//       child: pw.Row(
//         children: [
//           pw.Container(
//             width: 22,
//             height: 22,
//             child: pw.Image(pw.MemoryImage(iconBytes)),
//           ),
//           pw.SizedBox(width: 12),
//           pw.Text(value, style: pw.TextStyle(font: customFont, fontSize: 18)),
//         ],
//       ),
//     );
//   }

//   static String _extractInches(String input) {
//     final match = RegExp(r'(\d{2}\.?\d*)').firstMatch(input);
//     return match != null ? '${match.group(1)}"' : input;
//   }
// }

// // ================== POZIV SA SCREENA ==================

// Future<void> generateLeafletForEan(BuildContext context, String ean) async {
//   final session = await SessionManager().getUser();
//   if (session == null) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('Nema aktivne sesije!')));
//     return;
//   }

//   final product = await ApiService().getProductByBarcode(
//     ean,
//     int.parse(session['kup_id'].toString()),
//     int.parse(session['pos_id'].toString()),
//     session['hash1'],
//     session['hash2'],
//   );

//   if (product['success'] != 1) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('Greška: ${product['message']}')));

//     return;
//   }
//   print('API odgovor: $product');
//   final data = product['data'];
//   final opis = data['description'] as String? ?? '';
//   final liRegExp = RegExp(r'<li>(.*?)<\/li>', caseSensitive: false);
//   final parts = liRegExp
//       .allMatches(opis)
//       .map((m) => m.group(1)?.trim() ?? '')
//       .toList();

//   String diagonal = '';
//   String processor = '';
//   String gpu = '';
//   String ram = '';
//   String ssd = '';
//   String warranty = '';
//   String os = '';
//   String resolution = '';

//   for (final part in parts) {
//     final lower = part.toLowerCase();

//     if (RegExp(r'(\d+(\.\d+)?("| inch|inča))').hasMatch(lower)) {
//       diagonal = part;
//     } else if (lower.contains('procesor') ||
//         lower.contains('intel i') ||
//         lower.contains('i3') ||
//         lower.contains('i5') ||
//         lower.contains('i7') ||
//         lower.contains('i9') ||
//         lower.contains('ryzen') ||
//         lower.contains('amd ryzen')) {
//       processor = part;
//     } else if (lower.contains('graf') ||
//         lower.contains('grafička') ||
//         lower.contains('nvidia') ||
//         lower.contains('radeon') ||
//         lower.contains('uhd')) {
//       gpu = part;
//     } else if (RegExp(
//       r'(\d+\s*gb.*ram|\bram\b|\bDDR4\b |\bDDR5\b |\bmemorija\b|\bmhz\b)',
//     ).hasMatch(lower)) {
//       ram = part;
//     } else if (RegExp(
//       r'(ssd|hdd|\d+\s*gb.*ssd|\d+\s*tb.*ssd)',
//     ).hasMatch(lower)) {
//       ssd = part;
//     } else if (lower.contains('garanc')) {
//       warranty = part;
//     } else if (lower.contains('windows') ||
//         lower.contains('linux') ||
//         lower.contains('os')) {
//       os = part;
//     } else if (lower.contains('fhd') ||
//         lower.contains('HD') ||
//         lower.contains('4K') ||
//         lower.contains('FullHD') ||
//         lower.contains('Full HD') ||
//         lower.contains('Retina') ||
//         lower.contains('3840x2160') ||
//         lower.contains('1920x1080') ||
//         lower.contains('1366x768') ||
//         lower.contains('2560x1440') ||
//         lower.contains('3200x1800')) {
//       resolution = part; // 🔑 ovdje hvataš rezoluciju
//     }
//   }

//   // sve ostalo ide u descriptionBullets
//   final descriptionBullets = parts
//       .where(
//         (e) =>
//             e.isNotEmpty &&
//             e != diagonal &&
//             e != processor &&
//             e != gpu &&
//             e != ram &&
//             e != ssd &&
//             e != warranty &&
//             e != os,
//       )
//       .toList();

//   Uint8List? brandLogo;
//   Future<Uint8List?> _getBrandLogo(String brand) async {
//     final lower = brand.toLowerCase();
//     String? assetPath;

//     if (lower.contains('gigabyte')) {
//       assetPath = 'assets/stickers/icon_gigabyte.png';
//     } else if (lower.contains('msi')) {
//       assetPath = 'assets/stickers/icon_msi.png';
//     } else if (lower.contains('acer')) {
//       assetPath = 'assets/stickers/icon_acer.png';
//     } else if (lower.contains('asus')) {
//       assetPath = 'assets/stickers/icon_asus.png';
//     } else if (lower.contains('apple')) {
//       assetPath = 'assets/stickers/icon_apple.png';
//     } else if (lower.contains('lenovo')) {
//       assetPath = 'assets/stickers/icon_lenovo.png';
//     } else if (lower.contains('hp') || lower.contains('hewlett')) {
//       assetPath = 'assets/stickers/icon_hp.png';
//     } else if (lower.contains('dell') || lower.contains('dell')) {
//       assetPath = 'assets/stickers/icon_dell.png';
//     } else if (lower.contains('siemens') || lower.contains('siemens')) {
//       assetPath = 'assets/stickers/icon_fsiemens.png';
//     } else if (lower.contains('samsung') || lower.contains('samsung')) {
//       assetPath = 'assets/stickers/icon_samsung.png';
//     } else if (lower.contains('toshiba') || lower.contains('toshiba')) {
//       assetPath = 'assets/stickers/icon_toshiba.png';
//     } else if (lower.contains('huawei') || lower.contains('huawei')) {
//       assetPath = 'assets/stickers/icon_huawei.png';
//     } else if (lower.contains('razer') || lower.contains('razer')) {
//       assetPath = 'assets/stickers/icon_razer.png';
//     } else if (lower.contains('microsoft') || lower.contains('microsoft')) {
//       assetPath = 'assets/stickers/icon_microsoft.png';
//     }

//     if (assetPath != null) {
//       final data = await rootBundle.load(assetPath);
//       return data.buffer.asUint8List();
//     }
//     return null;
//   }

//   // prvo probaj uzeti iz API-ja
//   if (data['brand_logo'] != null && data['brand_logo'].toString().isNotEmpty) {
//     brandLogo = base64Decode(data['brand_logo']);
//   } else {
//     // ako nema u API-ju, probaj pronaći u lokalnim ikonama
//     brandLogo = await _getBrandLogo(data['Brand'] ?? '');
//   }

//   print('Processor: $processor');
//   print('GPU: $gpu');
//   final intelGpuSticker = await rootBundle.load('assets/stickers/intelgpu.png');
//   final intelSticker = await rootBundle.load('assets/stickers/intelcore.png');
//   final nvidiaSticker = await rootBundle.load('assets/stickers/rtx.png');
//   final amdSticker = await rootBundle.load('assets/stickers/radeon.png');
//   final ryzenSticker = await rootBundle.load('assets/stickers/ryzen.png');
//   final osIcon = await rootBundle.load('assets/stickers/icon_os.png');
//   final iconCpu = await rootBundle.load('assets/stickers/icon_cpu.png');
//   final iconRam = await rootBundle.load('assets/stickers/icon_ram.png');
//   final iconSsd = await rootBundle.load('assets/stickers/icon_ssd.png');
//   final iconGpu = await rootBundle.load('assets/stickers/icon_gpu.png');
//   final iconWarranty = await rootBundle.load(
//     'assets/stickers/icon_warranty.png',
//   );
//   final iconLaptop = await rootBundle.load('assets/stickers/icon_laptop.png');

//   // Dinamički biraj sticker za CPU
//   Uint8List cpuSticker = intelSticker.buffer.asUint8List();
//   if (processor.toLowerCase().contains('intel')) {
//     cpuSticker = intelSticker.buffer.asUint8List();
//   } else if (processor.toLowerCase().contains('ryzen')) {
//     cpuSticker = ryzenSticker.buffer.asUint8List();
//   } else if (processor.toLowerCase().contains('amd')) {
//     cpuSticker = amdSticker.buffer.asUint8List();
//   }

//   // GPU sticker
//   final gpuLower = gpu.toLowerCase();
//   Uint8List gpuSticker = nvidiaSticker.buffer.asUint8List();
//   if (gpuLower.contains('intel uhd')) {
//     gpuSticker = intelGpuSticker.buffer.asUint8List();
//   } else if (gpuLower.contains('nvidia') || gpuLower.contains('rtx')) {
//     gpuSticker = nvidiaSticker.buffer.asUint8List();
//   } else if (gpuLower.contains('amd') || gpuLower.contains('radeon')) {
//     gpuSticker = amdSticker.buffer.asUint8List();
//   }
//   // Učitaj custom font
//   final fontData = await rootBundle.load('assets/fonts/Montserrat-Regular.ttf');
//   final customFont = pw.Font.ttf(fontData);

//   final pdfBytes = await LeafletGenerator().generateLeaflet(
//     brand: data['Brand'] ?? '',
//     model: data['Model'] ?? '',
//     processor: processor,
//     ram: ram,
//     ssd: ssd,
//     gpu: gpu,
//     os: '', // možeš dodati ako imaš OS info
//     warranty: warranty,
//     diagonal: diagonal,
//     resolution: resolution, // možeš dodati ako imaš rezoluciju
//     ean: data['EAN'] ?? '',
//     productId: data['ID'].toString(),
//     productName: data['name'] ?? '',
//     descriptionBullets: descriptionBullets.cast<String>(),
//     brandLogo: brandLogo ?? Uint8List(0),
//     cpuSticker: cpuSticker,

//     gpuSticker: gpuSticker,
//     amdSticker: amdSticker.buffer.asUint8List(),
//     ryzenSticker: ryzenSticker.buffer.asUint8List(),
//     osIcon: osIcon.buffer.asUint8List(),
//     iconCpu: iconCpu.buffer.asUint8List(),
//     iconRam: iconRam.buffer.asUint8List(),

//     iconSsd: iconSsd.buffer.asUint8List(),
//     iconGpu: iconGpu.buffer.asUint8List(),
//     iconOs: osIcon.buffer.asUint8List(),
//     iconWarranty: iconWarranty.buffer.asUint8List(),
//     iconLaptop: iconLaptop.buffer.asUint8List(),
//     customFont: customFont,
//   );

//   await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
// }

//NOVI KOD
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/services.dart' show rootBundle;
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:flutter/material.dart';
// import 'package:digitalisapp/services/api_service.dart';
// import 'package:digitalisapp/core/utils/session_manager.dart';

// enum LeafletType { laptop, tv, white }

// class LeafletGenerator {
//   final LeafletType type;
//   LeafletGenerator({this.type = LeafletType.laptop});

//   Future<void> addLeafletPage({
//     required pw.Document pdf,
//     required String brand,
//     required String model,
//     required String processor,
//     required String ram,
//     required String ssd,
//     required String gpu,
//     required String os,
//     required String warranty,
//     required String diagonal,
//     required String resolution,
//     required String ean,
//     required String productId,
//     required String productName,
//     required List<String> descriptionBullets,
//     required Uint8List brandLogo,
//     required Uint8List cpuSticker,
//     required Uint8List gpuSticker,
//     required Uint8List osIcon,
//     required Uint8List iconCpu,
//     required Uint8List iconRam,
//     required Uint8List iconSsd,
//     required Uint8List iconGpu,
//     required Uint8List iconOs,
//     required Uint8List iconWarranty,
//     required Uint8List iconLaptop,
//     required pw.Font customFont,
//   }) async {
//     final ime = productName.replaceAll(' ', '');

//     pw.Widget leftBlock;
//     pw.Widget rightBlock;

//     switch (type) {
//       case LeafletType.laptop:
//         leftBlock = pw.Container(
//           width: 250,
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Stack(
//                 alignment: pw.Alignment.center,
//                 children: [
//                   pw.Image(pw.MemoryImage(iconLaptop), width: 220, height: 170),
//                   pw.Container(
//                     width: 220,
//                     height: 170,
//                     alignment: pw.Alignment.center,
//                     child: pw.Column(
//                       mainAxisSize: pw.MainAxisSize.min,
//                       children: [
//                         pw.Text(
//                           resolution,
//                           style: pw.TextStyle(
//                             font: customFont,
//                             fontSize: 14,
//                             fontWeight: pw.FontWeight.bold,
//                             color: PdfColors.black,
//                           ),
//                           textAlign: pw.TextAlign.center,
//                         ),
//                         if (diagonal.isNotEmpty)
//                           pw.Text(
//                             _extractInches(diagonal),
//                             style: pw.TextStyle(
//                               font: customFont,
//                               fontSize: 28,
//                               fontWeight: pw.FontWeight.bold,
//                               color: PdfColors.black,
//                             ),
//                             textAlign: pw.TextAlign.center,
//                           ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//               pw.SizedBox(height: 24),
//               if (brandLogo.isNotEmpty)
//                 pw.Image(pw.MemoryImage(brandLogo), height: 50)
//               else
//                 pw.Text(
//                   brand,
//                   style: pw.TextStyle(
//                     font: customFont,
//                     fontSize: 32,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//               pw.Text(
//                 "Model: $model",
//                 style: pw.TextStyle(font: customFont, fontSize: 22),
//                 maxLines: 1,
//                 overflow: pw.TextOverflow.visible,
//               ),
//               pw.SizedBox(height: 24),
//               _buildSpecRow(iconCpu, processor, customFont),
//               _buildSpecRow(iconRam, ram, customFont),
//               _buildSpecRow(iconSsd, ssd, customFont),
//               _buildSpecRow(iconGpu, gpu, customFont),
//               _buildSpecRow(iconOs, os, customFont),
//               _buildSpecRow(iconWarranty, warranty, customFont),
//             ],
//           ),
//         );
//         rightBlock = pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           children: [
//             pw.Row(
//               mainAxisSize: pw.MainAxisSize.min,
//               children: [
//                 pw.Image(pw.MemoryImage(cpuSticker), height: 80),
//                 if (gpuSticker.isNotEmpty) ...[
//                   pw.SizedBox(width: 12),
//                   pw.Image(pw.MemoryImage(gpuSticker), height: 80),
//                 ],
//               ],
//             ),
//             pw.SizedBox(height: 20),
//             // pw.Column(
//             //   crossAxisAlignment: pw.CrossAxisAlignment.start,
//             //   children: descriptionBullets
//             //       .where((b) => b.trim().isNotEmpty)
//             //       .map(
//             //         (b) => pw.Bullet(
//             //           text: b,
//             //           style: pw.TextStyle(font: customFont, fontSize: 16),
//             //         ),
//             //       )
//             //       .toList(),
//             // ),
//             pw.SizedBox(height: 32),
//             pw.Column(
//               children: [
//                 pw.SizedBox(height: 150),
//                 pw.Text(
//                   "Skeniraj QR kod za više informacija",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.BarcodeWidget(
//                   barcode: pw.Barcode.qrCode(),
//                   data: "https://www.dstore.ba/$productId/$ime",
//                   width: 100,
//                   height: 100,
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.Text(
//                   "EAN: $ean",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         );
//         break;

//       case LeafletType.tv:
//         leftBlock = pw.Container(
//           width: 280, // povećano sa 250
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               // ...existing code...
//               pw.Text(
//                 "Model: $model",
//                 style: pw.TextStyle(
//                   font: customFont,
//                   fontSize: 20,
//                 ), // smanjen font
//                 maxLines: 1,
//                 overflow: pw.TextOverflow.visible,
//               ),
//               pw.SizedBox(height: 24),
//               _buildSpecRow(iconCpu, processor, customFont, fontSize: 16),
//               _buildSpecRow(iconRam, ram, customFont, fontSize: 16),
//               _buildSpecRow(iconSsd, ssd, customFont, fontSize: 16),
//               _buildSpecRow(iconGpu, gpu, customFont, fontSize: 16),
//               _buildSpecRow(iconOs, os, customFont, fontSize: 16),
//               _buildSpecRow(iconWarranty, warranty, customFont, fontSize: 16),
//             ],
//           ),
//         );
//         rightBlock = pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           children: [
//             pw.Text(
//               diagonal,
//               style: pw.TextStyle(
//                 font: customFont,
//                 fontSize: 28,
//                 fontWeight: pw.FontWeight.bold,
//                 color: PdfColors.black,
//               ),
//             ),
//             pw.SizedBox(height: 20),
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: descriptionBullets
//                   .where((b) => b.trim().isNotEmpty)
//                   .map(
//                     (b) => pw.Bullet(
//                       text: b,
//                       style: pw.TextStyle(font: customFont, fontSize: 16),
//                     ),
//                   )
//                   .toList(),
//             ),
//             pw.SizedBox(height: 32),
//             pw.Column(
//               children: [
//                 pw.Text(
//                   "Skeniraj QR kod za više informacija",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.BarcodeWidget(
//                   barcode: pw.Barcode.qrCode(),
//                   data: "https://www.dstore.ba/$productId/$ime",
//                   width: 100,
//                   height: 100,
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.Text(
//                   "EAN: $ean",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         );
//         break;

//       case LeafletType.white:
//         leftBlock = pw.Container(
//           width: 250,
//           child: pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Image(pw.MemoryImage(iconLaptop), width: 220, height: 170),
//               pw.SizedBox(height: 24),
//               pw.Text(
//                 brand,
//                 style: pw.TextStyle(
//                   font: customFont,
//                   fontSize: 32,
//                   fontWeight: pw.FontWeight.bold,
//                 ),
//               ),
//               pw.Text(
//                 "Model: $model",
//                 style: pw.TextStyle(font: customFont, fontSize: 22),
//               ),
//               pw.SizedBox(height: 24),
//               _buildSpecRow(iconSsd, ssd, customFont),
//               _buildSpecRow(iconWarranty, warranty, customFont),
//             ],
//           ),
//         );
//         rightBlock = pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.end,
//           children: [
//             pw.SizedBox(height: 20),
//             pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: descriptionBullets
//                   .where((b) => b.trim().isNotEmpty)
//                   .map(
//                     (b) => pw.Bullet(
//                       text: b,
//                       style: pw.TextStyle(font: customFont, fontSize: 16),
//                     ),
//                   )
//                   .toList(),
//             ),
//             pw.SizedBox(height: 32),
//             pw.Column(
//               children: [
//                 pw.Text(
//                   "Skeniraj QR kod za više informacija",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.BarcodeWidget(
//                   barcode: pw.Barcode.qrCode(),
//                   data: "https://www.dstore.ba/$productId/$ime",
//                   width: 100,
//                   height: 100,
//                 ),
//                 pw.SizedBox(height: 6),
//                 pw.Text(
//                   "EAN: $ean",
//                   style: pw.TextStyle(font: customFont, fontSize: 12),
//                 ),
//               ],
//             ),
//           ],
//         );
//         break;
//     }

//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat.a4.landscape,
//         build: (context) {
//           return pw.Padding(
//             padding: const pw.EdgeInsets.all(24),
//             child: pw.Row(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 leftBlock,
//                 pw.SizedBox(width: 40),
//                 pw.Expanded(child: rightBlock),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }

//   pw.Widget _buildSpecRow(
//     Uint8List iconBytes,
//     String value,
//     pw.Font customFont, {
//     double fontSize = 18,
//   }) {
//     if (value.isEmpty || iconBytes.isEmpty) return pw.SizedBox();
//     return pw.Padding(
//       padding: const pw.EdgeInsets.symmetric(vertical: 4),
//       child: pw.Row(
//         children: [
//           pw.Container(
//             width: 22,
//             height: 22,
//             child: pw.Image(pw.MemoryImage(iconBytes)),
//           ),
//           pw.SizedBox(width: 12),
//           pw.Text(
//             value,
//             style: pw.TextStyle(
//               font: customFont,
//               fontSize: fontSize,
//               color: PdfColors.black,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   static String _extractInches(String input) {
//     final match = RegExp(r'(\d{2}\.?\d*)').firstMatch(input);
//     return match != null ? '${match.group(1)}"' : input;
//   }
// }

// // ================== POZIV ZA VIŠE EAN-OVA ==================
// Future<void> generateLeafletsForEans(
//   BuildContext context,
//   List<String> eans,
//   String type, // 'laptop', 'tv', 'white'
// ) async {
//   final session = await SessionManager().getUser();
//   if (session == null) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(SnackBar(content: Text('Nema aktivne sesije!')));
//     return;
//   }

//   final pdf = pw.Document();

//   for (final ean in eans) {
//     final product = await ApiService().getProductByBarcode(
//       ean,
//       int.parse(session['kup_id'].toString()),
//       int.parse(session['pos_id'].toString()),
//       session['hash1'],
//       session['hash2'],
//     );

//     if (product['success'] != 1) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('Greška: ${product['message']}')));
//       continue;
//     }

//     final data = product['data'];
//     final opis = data['description'] as String? ?? '';
//     final liRegExp = RegExp(r'<li>(.*?)<\/li>', caseSensitive: false);
//     final parts = liRegExp
//         .allMatches(opis)
//         .map((m) => m.group(1)?.trim() ?? '')
//         .toList();

//     String diagonal = '';
//     String processor = '';
//     String gpu = '';
//     String ram = '';
//     String ssd = '';
//     String warranty = '';
//     String os = '';
//     String resolution = '';

//     for (final part in parts) {
//       final lower = part.toLowerCase().trim();
//       final lowerNoDot = lower.endsWith('.')
//           ? lower.substring(0, lower.length - 1)
//           : lower;

//       if (RegExp(r'(\d+(\.\d+)?("| inch|inča))').hasMatch(lowerNoDot)) {
//         diagonal = part;
//       } else if (lowerNoDot.contains('procesor') ||
//           lowerNoDot.contains('intel i') ||
//           lowerNoDot.contains('i3') ||
//           lowerNoDot.contains('i5') ||
//           lowerNoDot.contains('i7') ||
//           lowerNoDot.contains('i9') ||
//           lowerNoDot.contains('ryzen')) {
//         processor = part;
//       } else if (lowerNoDot.contains('graf') ||
//           lowerNoDot.contains('grafička') ||
//           lowerNoDot.contains('nvidia') ||
//           lowerNoDot.contains('radeon') ||
//           lowerNoDot.contains('uhd') ||
//           lowerNoDot.contains('amd') ||
//           lowerNoDot.contains('geforce')) {
//         gpu = part;
//         print('GPU FALLBACK: $gpu');
//       } else if (RegExp(
//         r'(\d+\s*gb.*ram|\bram\b|\bDDR4\b |\bDDR5\b |\bmemorija\b|\bmhz\b)',
//       ).hasMatch(lowerNoDot)) {
//         ram = part;
//       } else if (RegExp(
//         r'(ssd|hdd|\d+\s*gb.*ssd|\d+\s*tb.*ssd)',
//       ).hasMatch(lowerNoDot)) {
//         ssd = part;
//       } else if (lowerNoDot.contains('garanc')) {
//         warranty = part;
//       } else if (lowerNoDot.contains('windows') ||
//           lowerNoDot.contains('linux') ||
//           lowerNoDot.contains('os')) {
//         os = part;
//       } else if (lowerNoDot.contains('fhd') ||
//           lowerNoDot.contains('hd') ||
//           lowerNoDot.contains('4k') ||
//           lowerNoDot.contains('fullhd') ||
//           lowerNoDot.contains('full hd') ||
//           lowerNoDot.contains('retina') ||
//           lowerNoDot.contains('3840x2160') ||
//           lowerNoDot.contains('1920x1080') ||
//           lowerNoDot.contains('1366x768') ||
//           lowerNoDot.contains('2560x1440') ||
//           lowerNoDot.contains('3200x1800')) {
//         resolution = part;
//       }
//     }

//     final descriptionBullets = parts
//         .where(
//           (e) =>
//               e.isNotEmpty &&
//               e != diagonal &&
//               e != processor &&
//               e != gpu &&
//               e != ram &&
//               e != ssd &&
//               e != warranty &&
//               e != os,
//         )
//         .toList();

//     Uint8List? brandLogo;
//     Future<Uint8List?> _getBrandLogo(String brand) async {
//       final lower = brand.toLowerCase();
//       String? assetPath;

//       if (lower.contains('gigabyte')) {
//         assetPath = 'assets/stickers/icon_gigabyte.png';
//       } else if (lower.contains('msi')) {
//         assetPath = 'assets/stickers/icon_msi.png';
//       } else if (lower.contains('acer')) {
//         assetPath = 'assets/stickers/icon_acer.png';
//       } else if (lower.contains('asus')) {
//         assetPath = 'assets/stickers/icon_asus.png';
//       } else if (lower.contains('apple')) {
//         assetPath = 'assets/stickers/icon_apple.png';
//       } else if (lower.contains('lenovo')) {
//         assetPath = 'assets/stickers/icon_lenovo.png';
//       } else if (lower.contains('hp') || lower.contains('hewlett')) {
//         assetPath = 'assets/stickers/icon_hp.png';
//       } else if (lower.contains('dell')) {
//         assetPath = 'assets/stickers/icon_dell.png';
//       } else if (lower.contains('siemens')) {
//         assetPath = 'assets/stickers/icon_fsiemens.png';
//       } else if (lower.contains('samsung')) {
//         assetPath = 'assets/stickers/icon_samsung.png';
//       } else if (lower.contains('toshiba')) {
//         assetPath = 'assets/stickers/icon_toshiba.png';
//       } else if (lower.contains('huawei')) {
//         assetPath = 'assets/stickers/icon_huawei.png';
//       } else if (lower.contains('razer')) {
//         assetPath = 'assets/stickers/icon_razer.png';
//       } else if (lower.contains('microsoft')) {
//         assetPath = 'assets/stickers/icon_microsoft.png';
//       }

//       if (assetPath != null) {
//         final data = await rootBundle.load(assetPath);
//         return data.buffer.asUint8List();
//       }
//       return null;
//     }

//     if (data['brand_logo'] != null &&
//         data['brand_logo'].toString().isNotEmpty) {
//       brandLogo = base64Decode(data['brand_logo']);
//     } else {
//       brandLogo = await _getBrandLogo(data['Brand'] ?? '');
//     }

//     final intelGpuSticker = await rootBundle.load(
//       'assets/stickers/intelgpu.png',
//     );
//     final intelSticker = await rootBundle.load('assets/stickers/intelcore.png');
//     final nvidiaSticker = await rootBundle.load('assets/stickers/rtx.png');
//     final amdSticker = await rootBundle.load('assets/stickers/radeon.png');
//     final ryzenSticker = await rootBundle.load('assets/stickers/ryzen.png');
//     final osIcon = await rootBundle.load('assets/stickers/icon_os.png');
//     final iconCpu = await rootBundle.load('assets/stickers/icon_cpu.png');
//     final iconRam = await rootBundle.load('assets/stickers/icon_ram.png');
//     final iconSsd = await rootBundle.load('assets/stickers/icon_ssd.png');
//     final iconGpu = await rootBundle.load('assets/stickers/icon_gpu.png');
//     final iconWarranty = await rootBundle.load(
//       'assets/stickers/icon_warranty.png',
//     );
//     final iconLaptop = await rootBundle.load('assets/stickers/icon_laptop.png');
//     final fontData = await rootBundle.load(
//       'assets/fonts/Montserrat-Regular.ttf',
//     );
//     final customFont = pw.Font.ttf(fontData);

//     Uint8List cpuSticker = intelSticker.buffer.asUint8List();
//     if (processor.toLowerCase().contains('intel')) {
//       cpuSticker = intelSticker.buffer.asUint8List();
//     } else if (processor.toLowerCase().contains('ryzen')) {
//       cpuSticker = ryzenSticker.buffer.asUint8List();
//     } else if (processor.toLowerCase().contains('amd')) {
//       cpuSticker = amdSticker.buffer.asUint8List();
//     }

//     final gpuLower = gpu.toLowerCase();
//     Uint8List gpuSticker = nvidiaSticker.buffer.asUint8List();
//     if (gpuLower.contains('intel uhd')) {
//       gpuSticker = intelGpuSticker.buffer.asUint8List();
//     } else if (gpuLower.contains('nvidia') || gpuLower.contains('rtx')) {
//       gpuSticker = nvidiaSticker.buffer.asUint8List();
//     } else if (gpuLower.contains('amd') || gpuLower.contains('radeon')) {
//       gpuSticker = amdSticker.buffer.asUint8List();
//     }

//     final leafletGen = type == 'tv'
//         ? LeafletGenerator(type: LeafletType.tv)
//         : type == 'white'
//         ? LeafletGenerator(type: LeafletType.white)
//         : LeafletGenerator(type: LeafletType.laptop);

//     await leafletGen.addLeafletPage(
//       pdf: pdf,
//       brand: data['Brand'] ?? '',
//       model: data['Model'] ?? '',
//       processor: processor,
//       ram: ram,
//       ssd: ssd,
//       gpu: gpu,
//       os: os,
//       warranty: warranty,
//       diagonal: diagonal,
//       resolution: resolution,
//       ean: data['EAN'] ?? '',
//       productId: data['ID'].toString(),
//       productName: data['name'] ?? '',
//       descriptionBullets: descriptionBullets,
//       brandLogo: brandLogo ?? Uint8List(0),
//       cpuSticker: cpuSticker,
//       gpuSticker: gpuSticker,
//       osIcon: osIcon.buffer.asUint8List(),
//       iconCpu: iconCpu.buffer.asUint8List(),
//       iconRam: iconRam.buffer.asUint8List(),
//       iconSsd: iconSsd.buffer.asUint8List(),
//       iconGpu: iconGpu.buffer.asUint8List(),
//       iconOs: osIcon.buffer.asUint8List(),
//       iconWarranty: iconWarranty.buffer.asUint8List(),
//       iconLaptop: iconLaptop.buffer.asUint8List(),
//       customFont: customFont,
//     );
//     print('GPU FINAL: $gpu');
//     print('iconGpu length: ${iconGpu.buffer.lengthInBytes}');
//   }

//   await Printing.layoutPdf(onLayout: (_) async => pdf.save());
// }
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
    required List<String> descriptionBullets,
    required Uint8List brandLogo,
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
          width: 250,
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
                pw.SizedBox(height: 150),
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
                alignment: pw.Alignment.center,
                children: [
                  pw.Image(pw.MemoryImage(iconTv!), width: 220, height: 170),
                  pw.Container(
                    width: 220,
                    height: 170,
                    alignment: pw.Alignment.center,
                    child: pw.Column(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          '${_extractInches(diagonal)} / ${_extractCm(diagonal)}',
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
                'Smart: ${os.isNotEmpty ? "Da" : "Ne"}',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(
                iconPorts!,
                'Konektori: HDMI x3, USB x1, CI+, Satelitski, LAN RJ-45',
                customFont,
                fontSize: 14,
              ),
              _buildSpecRow(iconAudio!, 'Audio: 20W', customFont, fontSize: 14),
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
            padding: const pw.EdgeInsets.all(24),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                leftBlock,
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
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
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

    final opis = data['description'] as String? ?? '';
    final liRegExp = RegExp(r'<li>(.*?)<\/li>', caseSensitive: false);
    final parts = liRegExp
        .allMatches(opis)
        .map((m) => m.group(1)?.trim() ?? '')
        .toList();

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
      final lowerNoDot = lower.endsWith('.')
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
          lowerNoDot.contains('ryzen')) {
        processor = part;
      } else if (lowerNoDot.contains('graf') ||
          lowerNoDot.contains('grafička') ||
          lowerNoDot.contains('nvidia') ||
          lowerNoDot.contains('radeon') ||
          lowerNoDot.contains('uhd') ||
          lowerNoDot.contains('amd') ||
          lowerNoDot.contains('geforce')) {
        gpu = part;
      } else if (RegExp(
        r'(\d+\s*gb.*ram|\bram\b|\bDDR4\b |\bDDR5\b |\bmemorija\b|\bmhz\b)',
      ).hasMatch(lowerNoDot)) {
        ram = part;
      } else if (RegExp(
        r'(ssd|hdd|\d+\s*gb.*ssd|\d+\s*tb.*ssd)',
      ).hasMatch(lowerNoDot)) {
        ssd = part;
      } else if (lowerNoDot.contains('garanc')) {
        warranty = part;
      } else if (lowerNoDot.contains('tizen') ||
          lowerNoDot.contains('webos') ||
          lowerNoDot.contains('android') ||
          lowerNoDot.contains('windows') ||
          lowerNoDot.contains('linux') ||
          lowerNoDot.contains('os')) {
        os = part;
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

    final descriptionBullets = parts
        .where(
          (e) =>
              e.isNotEmpty &&
              e != diagonal &&
              e != processor &&
              e != gpu &&
              e != ram &&
              e != ssd &&
              e != warranty &&
              e != os,
        )
        .toList();

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
        'assets/stickers/iucon_tizen.png',
      )).buffer.asUint8List();
    } else if (os.toLowerCase().contains('webos')) {
      osLogo = (await rootBundle.load(
        'assets/stickers/icon_weboswebos.png',
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

    await leafletGen.addLeafletPage(
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
      descriptionBullets: descriptionBullets,
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
