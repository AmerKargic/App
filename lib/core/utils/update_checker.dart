import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateChecker {
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('https://yourcompany.com/app/version.json'),
      );
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final latestVersion = data['version'] ?? '';
      final apkUrl = data['apk_url'] ?? '';
      final whatsNew = data['whats_new'] ?? '';
      final forceUpdate = data['force_update'] ?? false;

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (latestVersion.isEmpty || apkUrl.isEmpty) return;

      if (currentVersion != latestVersion) {
        showDialog(
          context: context,
          barrierDismissible:
              !forceUpdate, // <--- prevents closing by tap outside if forced
          builder: (_) => _UpdateDialog(
            apkUrl: apkUrl,
            whatsNew: whatsNew,
            latestVersion: latestVersion,
            forceUpdate: data['force_update'] ?? false,
          ),
        );
      }
    } catch (e) {
      // Optionally: Show error or ignore
    }
  }
}

class _UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final String whatsNew;
  final String latestVersion;
  final bool forceUpdate;
  const _UpdateDialog({
    required this.apkUrl,
    required this.whatsNew,
    required this.latestVersion,
    required this.forceUpdate,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool downloading = false;
  double progress = 0;
  String? status;

  void _startUpdate() async {
    setState(() {
      downloading = true;
      progress = 0;
      status = null;
    });

    try {
      OtaUpdate()
          .execute(widget.apkUrl, destinationFilename: 'myapp-latest.apk')
          .listen((OtaEvent event) {
            if (event.status == OtaStatus.DOWNLOADING) {
              setState(() {
                progress = double.tryParse(event.value ?? '0') ?? 0;
              });
            } else if (event.status == OtaStatus.INSTALLING) {
              setState(() {
                status = 'Installing...';
              });
            } else if (event.status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
              setState(() {
                status = 'Permission not granted for installation.';
              });
            } else if (event.status == OtaStatus.INTERNAL_ERROR) {
              setState(() {
                status = 'Internal error occurred.';
              });
            } else if (event.status == OtaStatus.DOWNLOAD_ERROR) {
              setState(() {
                status = 'Download error occurred.';
              });
            }
          });
    } catch (e) {
      setState(() {
        status = 'Update failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nova verzija (${widget.latestVersion}) dostupna!'),
      content: downloading
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress / 100),
                SizedBox(height: 16),
                Text('Preuzimanje: ${progress.toStringAsFixed(1)}%'),
                if (status != null) ...[
                  SizedBox(height: 8),
                  Text(status!, style: TextStyle(color: Colors.red)),
                ],
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.whatsNew.isNotEmpty) ...[
                  Text(
                    'Šta je novo:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 6),
                  Text(widget.whatsNew),
                  SizedBox(height: 12),
                ],
                Text('Želite li ažurirati aplikaciju sada?'),
              ],
            ),
      actions: downloading
          ? []
          : widget.forceUpdate == true
          ? [ElevatedButton(onPressed: _startUpdate, child: Text('Ažuriraj'))]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Kasnije'),
              ),
              ElevatedButton(onPressed: _startUpdate, child: Text('Ažuriraj')),
            ],
    );
  }
}
