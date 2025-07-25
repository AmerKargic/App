import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverOrderScreen extends StatelessWidget {
  final DriverOrder order;
  final int scannedBoxCount;

  DriverOrderScreen({Key? key, required this.order, this.scannedBoxCount = 0})
    : super(key: key);

  void _launchNavigation() async {
    final address = Uri.encodeComponent(order.kupac.adresa);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  void _confirmDelivery(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dostava je potvrđena')));
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kupac = order.kupac;
    final naplata = order.iznos;
    final isPovrat = naplata < 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Pregled narudžbe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text(
              "Kupac: ${kupac.naziv}",
              style: GoogleFonts.inter(fontSize: 18),
            ),
            Text("Adresa: ${kupac.adresa}"),
            Text("Telefon: ${kupac.telefon}"),
            const SizedBox(height: 12),
            if (order.napomena.isNotEmpty)
              Text(
                "Napomena: ${order.napomena}",
                style: const TextStyle(color: Colors.black87),
              ),
            if (order.napomenaVozac.isNotEmpty)
              Text(
                "Napomena vozač: ${order.napomenaVozac}",
                style: const TextStyle(color: Colors.red),
              ),
            _buildSectionTitle("Status kutija"),
            Text("Skenirano: $scannedBoxCount/${order.brojKutija}"),
            _buildSectionTitle("Plaćanje"),
            Text(
              naplata > 0
                  ? "Potrebno naplatiti: ${naplata.toStringAsFixed(2)} KM"
                  : isPovrat
                  ? "⚠️ Povrat novca kupcu: ${naplata.abs().toStringAsFixed(2)} KM"
                  : "Nema naplate",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPovrat ? Colors.red : Colors.green.shade700,
              ),
            ),
            _buildSectionTitle("Artikli"),
            ...order.stavke.map((a) => Text("- ${a.naziv} × ${a.kol}")),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.navigation),
              label: const Text("Pokreni navigaciju"),
              onPressed: _launchNavigation,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: const Text("Potvrdi dostavu"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _confirmDelivery(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.info),
              label: const Text("Kraj dana (uskoro)"),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Ova funkcija će uskoro biti aktivna."),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
