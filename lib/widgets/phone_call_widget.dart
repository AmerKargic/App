import 'package:digitalisapp/models/driver_order_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneCallWidget extends StatelessWidget {
  final Kupac kupac;

  const PhoneCallWidget({Key? key, required this.kupac}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final phones = kupac.phoneNumbers;

    if (phones.isEmpty) {
      return Container(); // No phones available
    }

    if (phones.length == 1) {
      // Single phone - direct call button
      return ElevatedButton.icon(
        onPressed: () => _makeCall(context, phones.first),
        icon: Icon(Icons.phone),
        label: Text(phones.first.type),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }

    // Multiple phones - show selection dialog
    return ElevatedButton.icon(
      onPressed: () => _showPhoneSelection(context, phones),
      icon: Icon(Icons.phone),
      label: Text('Pozovi (${phones.length})'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _showPhoneSelection(BuildContext context, List<PhoneNumber> phones) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Odaberite broj telefona',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...phones
                  .map(
                    (phone) => ListTile(
                      leading: Icon(
                        phone.isMobile ? Icons.smartphone : Icons.phone,
                        color: phone.isMobile ? Colors.blue : Colors.green,
                      ),
                      title: Text(phone.isMobile ? 'Mobilni' : 'Fiksni'),
                      subtitle: Text(phone.number),
                      trailing: Icon(Icons.call),
                      onTap: () {
                        Navigator.pop(context);
                        _makeCall(context, phone);
                      },
                    ),
                  )
                  .toList(),
              SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Otkazi'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _makeCall(BuildContext context, PhoneNumber phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone.callableNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        _showError(context, 'Nije moguće pozvati ${phone.number}');
      }
    } catch (e) {
      _showError(context, 'Greška pri pozivanju: $e');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
