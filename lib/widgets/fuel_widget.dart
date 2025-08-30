import 'package:flutter/material.dart';

class FuelDialog extends StatefulWidget {
  final int? defaultOdometer;
  const FuelDialog({this.defaultOdometer, super.key});

  @override
  State<FuelDialog> createState() => _FuelDialogState();
}

class _FuelDialogState extends State<FuelDialog> {
  final _litersController = TextEditingController();
  final _odometerController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.defaultOdometer != null) {
      _odometerController.text = widget.defaultOdometer.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_gas_station, size: 48, color: Colors.blueAccent),
              const SizedBox(height: 12),
              Text(
                "Unos sipanja goriva",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _litersController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: "Količina (litara)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _odometerController,
                keyboardType: TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                  labelText: "Kilometraža (km)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _noteController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  labelText: "Napomena (opcionalno)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_alt_outlined),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.close),
                    label: Text("Preskoči"),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                  ElevatedButton.icon(
                    icon: Icon(Icons.check),
                    label: Text("Spremi"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, {
                        'liters': double.tryParse(_litersController.text) ?? 0,
                        'odometer': int.tryParse(_odometerController.text) ?? 0,
                        'note': _noteController.text,
                        'timestamp': DateTime.now().toIso8601String(),
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
