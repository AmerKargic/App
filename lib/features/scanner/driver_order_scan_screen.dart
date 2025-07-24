import 'package:digitalisapp/features/maps/driver_navigation_screen.dart';
import 'package:digitalisapp/features/scanner/warehouse_scanner_screen.dart';
import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:digitalisapp/services/driver_api_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverOrderScanScreen extends StatefulWidget {
  const DriverOrderScanScreen({super.key});

  @override
  State<DriverOrderScanScreen> createState() => _DriverOrderScanScreenState();
}

class _DriverOrderScanScreenState extends State<DriverOrderScanScreen> {
  DriverOrder? order;
  int scannedBoxes = 0;
  Set<int> scannedBoxIds = {};
  String statusMessage = '';
  bool loading = false;

  Future<void> fetchOrder(String code) async {
    setState(() {
      loading = true;
      statusMessage = '';
      scannedBoxes = 0;
      scannedBoxIds.clear();
      order = null;
    });

    final response = await DriverApiService.fetchOrder(code);
    setState(() => loading = false);

    if (response['success'] == 1) {
      final fetched = DriverOrder.fromJson(response['data']);
      setState(() {
        order = fetched;
        scannedBoxIds.add(_extractBoxNumber(code));
        scannedBoxes = 1;
        statusMessage = "Skenirana kutija 1/${fetched.brojKutija}";
      });
    } else {
      setState(() {
        statusMessage = response['message'] ?? 'Greška.';
      });
    }
  }

  void scanNextBox(String code) async {
    if (order == null) return;

    final expectedOid = order!.oid;

    if (!code.contains('ku') || !code.endsWith('$expectedOid')) {
      setState(() => statusMessage = '❌ Pogrešan barkod.');
      return;
    }

    final boxNumber = _extractBoxNumber(code);
    if (scannedBoxIds.contains(boxNumber)) {
      setState(() => statusMessage = '❗ Kutija $boxNumber već skenirana.');
      return;
    }

    final response = await DriverApiService.scanBox(code, expectedOid);

    if (response['success'] == 1) {
      setState(() {
        scannedBoxIds.add(boxNumber);
        scannedBoxes = scannedBoxIds.length;
        statusMessage = "✅ Skenirano $scannedBoxes/${order!.brojKutija} kutija";
      });
    } else {
      setState(() {
        statusMessage = response['message'] ?? 'Greška skeniranja kutije.';
      });
    }
  }

  int _extractBoxNumber(String code) {
    final parts = code.split('ku');
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? 0;
    }
    return 0;
  }

  //STARA NAVIGACIJA OTVARA GOOGLE MAPS
  /*void startNavigation() async {
    if (order?.kupac == null) return;
    final address = Uri.encodeComponent(order!.kupac.fullAddress());
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }*/
  void startNavigation() {
    if (order?.kupac == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DriverNavigationScreen(
          address: order!.kupac.fullAddress(),
          customerName: order!.kupac.naziv,
          orderId: order!.oid.toString(),
        ),
      ),
    );
  }

  Widget buildOrderDetails() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (order == null) {
      return const SizedBox.shrink();
    }

    final kupac = order!.kupac;
    final isPovrat = order!.trebaVratitiNovac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "📦 Narudžba #${order!.oid}",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text("👤 Kupac: ${kupac.naziv}", style: GoogleFonts.inter()),
        Text("📍 Adresa: ${kupac.fullAddress()}", style: GoogleFonts.inter()),
        Text("📞 Telefon: ${kupac.telefon}", style: GoogleFonts.inter()),
        const SizedBox(height: 12),
        if (order!.napomena.isNotEmpty)
          Text(
            "📝 Napomena: ${order!.napomena}",
            style: const TextStyle(color: Colors.black87),
          ),
        if (order!.napomenaVozac.isNotEmpty)
          Text(
            "🛑 Vozaču: ${order!.napomenaVozac}",
            style: const TextStyle(color: Colors.red),
          ),
        const SizedBox(height: 12),
        Text(
          order!.iznos > 0
              ? "💰 Naplatiti: ${order!.iznos.toStringAsFixed(2)} KM"
              : isPovrat
              ? "↩️ Povrat: ${order!.iznos.abs().toStringAsFixed(2)} KM"
              : "✅ Bez naplate",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPovrat ? Colors.red : Colors.green.shade800,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "🧾 Artikli:",
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ...order!.stavke.map((a) => Text("• ${a.naziv} × ${a.kol}")),
        const SizedBox(height: 16),
        if (scannedBoxes < order!.brojKutija)
          HardwareBarcodeInput(
            hintText: "Skeniraj sljedeću kutiju...",
            onBarcodeScanned: scanNextBox,
          ),
        if (scannedBoxes == order!.brojKutija)
          ElevatedButton.icon(
            icon: const Icon(Icons.navigation),
            label: const Text("Navigacija do kupca"),
            onPressed: startNavigation,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Skeniranje paketa")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            HardwareBarcodeInput(
              hintText: "Skeniraj barkod paketa...",
              onBarcodeScanned: fetchOrder,
            ),
            // Additional test button specifically for this screen
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                fetchOrder("KU1KU2355444");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text("Test Order Code: KU1KU2355444"),
            ),
            const SizedBox(height: 20),
            if (statusMessage.isNotEmpty)
              Text(statusMessage, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 16),
            buildOrderDetails(),
          ],
        ),
      ),
    );
  }
}
