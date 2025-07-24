import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:url_launcher/url_launcher.dart';
// Add HTML rendering package if you need it
// import 'package:flutter_html/flutter_html.dart';

class DriverOrderDetailsScreen extends StatefulWidget {
  final DriverOrder order;

  const DriverOrderDetailsScreen({super.key, required this.order});

  @override
  State<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState extends State<DriverOrderDetailsScreen> {
  final Set<int> scannedBoxes = {};
  bool loading = false;
  String message = '';

  @override
  void initState() {
    super.initState();
    // Debug print to check data
    debugPrint("Order data: ${widget.order.toJson()}");
  }

  Future<void> scanBox(String barcode) async {
    // Make sure barcode is lowercase to match server expectations
    final formattedBarcode = barcode.toLowerCase();

    setState(() {
      loading = true;
      message = '';
    });

    final response = await DriverApiService.post('driver_scan_box.php', {
      'code': formattedBarcode,
      'oid': widget.order.oid.toString(),
    });

    setState(() => loading = false);

    if (response['success'] == 1) {
      final int boxNumber = _extractBoxNumber(formattedBarcode);
      if (!scannedBoxes.contains(boxNumber)) {
        setState(() {
          scannedBoxes.add(boxNumber);
          message = "✅ Kutija $boxNumber skenirana!";
        });
      } else {
        setState(() {
          message = "⚠️ Kutija $boxNumber je već skenirana.";
        });
      }
    } else {
      setState(() {
        message = response['message'] ?? 'Greška prilikom skeniranja kutije.';
      });
    }
  }

  int _extractBoxNumber(String code) {
    final parts = code.split('ku');
    return (parts.length >= 2) ? int.tryParse(parts[1]) ?? 0 : 0;
  }

  Future<void> confirmDelivery() async {
    setState(() => loading = true);

    final response = await DriverApiService.post(
      'driver_confirm_delivery.php',
      {'oid': widget.order.oid.toString()},
    );

    setState(() => loading = false);

    if (response['success'] == 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Dostava potvrđena!')));
      Navigator.pop(context);
    } else {
      setState(() {
        message = response['message'] ?? 'Greška prilikom potvrde dostave.';
      });
    }
  }

  Future<void> startNavigation() async {
    // Only navigate if there's an address
    if (widget.order.kupac.adresa.isEmpty) {
      setState(() {
        message = "Nije moguće pokrenuti navigaciju - nedostaje adresa";
      });
      return;
    }

    final address = Uri.encodeComponent(widget.order.kupac.fullAddress());
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      setState(() {
        message = "Nije moguće pokrenuti navigaciju";
      });
    }
  }

  // Convert simple HTML to plain text
  String _stripHtml(String html) {
    return html
        .replaceAll('<br>', '\n')
        .replaceAll('</br>', '\n')
        .replaceAll('<strong>', '')
        .replaceAll('</strong>', '');
  }

  @override
  Widget build(BuildContext context) {
    final allBoxesScanned = scannedBoxes.length == widget.order.brojKutija;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text('Detalji narudžbe', style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFF3F4F6),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ListView(
            children: [
              _buildOrderDetails(),
              const SizedBox(height: 16),
              if (!allBoxesScanned) _buildScanBoxSection(),
              if (allBoxesScanned) _buildActionButtons(),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    message,
                    style: GoogleFonts.inter(
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              // Debug test buttons
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => scanBox('ku1ku${widget.order.oid}'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                child: Text("Test Scan Box 1"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final kupac = widget.order.kupac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Narudžba #${widget.order.oid}',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (kupac.naziv.isNotEmpty)
          Text('👤 ${kupac.naziv}', style: GoogleFonts.inter(fontSize: 16)),
        if (kupac.fullAddress().isNotEmpty)
          Text('📍 ${kupac.fullAddress()}', style: GoogleFonts.inter()),
        if (kupac.telefon.isNotEmpty)
          Text('📞 ${kupac.telefon}', style: GoogleFonts.inter()),
        if (widget.order.napomena.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '📝 Napomena: ${widget.order.napomena}',
            style: GoogleFonts.inter(color: Colors.grey.shade700),
          ),
        ],
        if (widget.order.napomenaVozac.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '🚨 Napomena vozaču: ${_stripHtml(widget.order.napomenaVozac)}',
            style: GoogleFonts.inter(color: Colors.red.shade600),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          widget.order.iznos > 0
              ? '💰 Naplata: ${widget.order.iznos.toStringAsFixed(2)} KM'
              : widget.order.trebaVratitiNovac
              ? '↩️ Povrat: ${widget.order.iznos.abs().toStringAsFixed(2)} KM'
              : '✅ Bez naplate',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: widget.order.trebaVratitiNovac ? Colors.red : Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '📦 Kutije skenirane: ${scannedBoxes.length}/${widget.order.brojKutija}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        // Replace the current items display code in _buildOrderDetails() method
        // Find this part:
        Text(
          '📋 Artikli:',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        if (widget.order.stavke.isEmpty)
          Text('Nema artikala', style: GoogleFonts.inter(color: Colors.grey)),
        for (var stavka in widget.order.stavke)
          Text('• ${stavka.naziv} × ${stavka.kol}', style: GoogleFonts.inter()),

        // Replace with this improved version:
        Text(
          '📋 Artikli:',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (widget.order.stavke.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Nema artikala',
              style: GoogleFonts.inter(color: Colors.grey.shade700),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < widget.order.stavke.length; i++) ...[
                  _buildItemCard(widget.order.stavke[i]),
                  if (i < widget.order.stavke.length - 1)
                    Divider(height: 1, color: Colors.grey.shade300),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // Add this method to the _DriverOrderDetailsScreenState class
  Widget _buildItemCard(Stavka stavka) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stavka.naziv,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                if (stavka.ean.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'EAN: ${stavka.naziv}',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '×${stavka.kol}',
                        style: GoogleFonts.inter(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (stavka.cijena > 0)
                      Text(
                        '${stavka.cijena.toStringAsFixed(2)} KM',
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Right side - total price
          if (stavka.kol * stavka.cijena > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(stavka.kol * stavka.cijena).toStringAsFixed(2)} KM',
                style: GoogleFonts.inter(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScanBoxSection() => Column(
    children: [
      HardwareBarcodeInput(
        hintText: 'Skeniraj kutiju...',
        onBarcodeScanned: scanBox,
      ),
      const SizedBox(height: 16),
      // Test button for debugging
      ElevatedButton(
        onPressed: () => scanBox('ku1ku${widget.order.oid}'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        child: const Text("Test Scan Box 1"),
      ),
    ],
  );

  Widget _buildActionButtons() => Column(
    children: [
      ElevatedButton.icon(
        icon: const Icon(Icons.navigation),
        label: const Text('Navigacija'),
        // FIX: Use widget.order.kupac instead of just kupac
        onPressed: widget.order.kupac.adresa.isNotEmpty
            ? startNavigation
            : null,
      ),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        icon: const Icon(Icons.check_circle),
        label: const Text('Potvrdi dostavu'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        onPressed: confirmDelivery,
      ),
    ],
  );
}
