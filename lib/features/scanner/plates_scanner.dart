import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:digitalisapp/core/utils/session_manager.dart';
import 'package:digitalisapp/features/scanner/driver_order_scan_screen.dart';

import 'package:digitalisapp/services/offline_services.dart';
import 'package:digitalisapp/widgets/fuel_widget.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:digitalisapp/lib/services/driver_api_service.dart'; // prilagodi putanju ako treba
import '../../services/driver_api_service.dart';

class LicensePlateScanner extends StatefulWidget {
  final bool startInStillsMode;
  final void Function(String plate)? onDetected;
  const LicensePlateScanner({
    super.key,
    this.onDetected,
    this.startInStillsMode = false,
  });

  @override
  State<LicensePlateScanner> createState() => _LicensePlateScannerState();
}

class _LicensePlateScannerState extends State<LicensePlateScanner> {
  CameraController? _controller;
  late final TextRecognizer _recognizer;

  bool _processing = false;
  bool _found = false;
  bool _torchOn = false;
  bool _stillsMode = false;

  Timer? _throttle;

  final _bih = RegExp(
    r'\b([A-ZŠĐŽČĆ]{2})-(\d{3})-([A-ZŠĐŽČĆ]{2})\b',
    unicode: true,
  );
  final _euLike = RegExp(r'\b([A-Z]{2})[-\s]?(\d{3})[-\s]?([A-Z]{2})\b');
  final _numLet = RegExp(r'\b(\d{2,3})[-\s]?([A-Z]{2})[-\s]?(\d{2,3})\b');

  static const double _roiW = 0.80;
  static const double _roiH = 0.28;

  @override
  void initState() {
    super.initState();
    _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _stillsMode = widget.startInStillsMode;
    _init();
  }

  Future<void> _init() async {
    if (await Permission.camera.request().isDenied) return;

    final cams = await availableCameras();
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );

    _controller = CameraController(
      back,
      Platform.isAndroid ? ResolutionPreset.medium : ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    await _safeSetFocusExposure(const Offset(0.5, 0.5));

    if (!_stillsMode) {
      await _controller!.startImageStream(_onNewFrame);
    }
    if (mounted) setState(() {});
  }

  Future<void> _onNewFrame(CameraImage image) async {
    if (_processing || _found || _stillsMode) return;
    if (_throttle != null && _throttle!.isActive) return;
    _throttle = Timer(const Duration(milliseconds: 350), () {});

    _processing = true;
    try {
      final input = _toInputImage(
        image,
        _controller!.description.sensorOrientation,
      );
      final text = await _recognizer.processImage(input);

      final plate = _extractPlateFrom(
        text,
        image.width.toDouble(),
        image.height.toDouble(),
      );
      if (plate != null) {
        await _onHit(plate);
      }
    } catch (_) {
      // po želji log
    } finally {
      _processing = false;
    }
  }

  Future<void> _captureAndRecognize() async {
    if (_processing || _found || _controller == null) return;
    _processing = true;
    try {
      await _safeSetFocusExposure(const Offset(0.5, 0.5));
      final XFile shot = await _controller!.takePicture();

      final input = InputImage.fromFilePath(shot.path);
      final text = await _recognizer.processImage(input);

      final plate = _extractPlateHeuristic(text);
      if (plate != null) {
        await _onHit(plate);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nema jasne tablice — pokušaj opet.')),
          );
        }
      }
    } catch (_) {
      // po želji log
    } finally {
      _processing = false;
    }
  }

  // kada se pronadje tablica u kadru poziva se ova funkcija da bi se provjerile informacije na serveru i ako se poklapaju vozacu se prikaziva vozilo koje je skenirao i moze ga zauzeti ili prekinuti pa skenirati ponovo
  Future<void> _onHit(String plate) async {
    _found = true;
    try {
      await _controller?.stopImageStream();
    } catch (_) {}
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => FutureBuilder<Map<String, dynamic>>(
          future: DriverApiService.getTruck(plate),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AlertDialog(
                title: Text('Pretraga vozila'),
                content: SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final data = snapshot.data!;
            return AlertDialog(
              title: Text('Tablica: $plate'),
              content: Text(
                data['success'] == 1
                    ? 'Vozilo: ${data['truck'] ?? data}'
                    : (data['message'] ?? 'Greška'),
              ),
              actions: [
                if (data['success'] == 1)
                  ElevatedButton.icon(
                    icon: Icon(Icons.directions_car),
                    label: Text("Zauzmi vozilo"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () async {
                      final user = await SessionManager().getUser();
                      final driverId = user?['kup_id'] ?? 0;
                      final driverName = user?['name'] ?? '';

                      final resp = await DriverApiService.takeTruck(
                        plate,
                        driverId,
                        driverName,
                      );

                      await OfflineService().logActivity(
                        typeId: OfflineService.DRIVER_TOOK_TRUCK,
                        description: 'Vozač zauzeo vozilo',
                        relatedId: null,
                        text: 'Vozač zauzeo vozilo',
                        extraData: {
                          'plate': plate,
                          'driver_id': driverId,
                          'driver_name': driverName,
                          'server_response': resp,
                          'timestamp': DateTime.now().toIso8601String(),
                        },
                      );

                      if (resp['success'] == 1) {
                        final truckId =
                            int.tryParse(resp['truck_id']?.toString() ?? '') ??
                            0;

                        await SessionManager().setVehicleInfo(
                          truckId,
                          resp['truck_plate'] ?? plate,
                        );

                        // AUTOMATSKI OTVORI FUEL DIALOG
                        final fuelEntry =
                            await showDialog<Map<String, dynamic>>(
                              context: context,
                              barrierDismissible: false,
                              builder: (ctx) => FuelDialog(),
                            );

                        if (fuelEntry != null) {
                          final vehicleInfo = await SessionManager()
                              .getVehicleInfo();
                          await OfflineService().logActivity(
                            typeId: OfflineService.DRIVER_ADDED_FUEL,
                            description: 'Vozač sipao gorivo',
                            extraData: {
                              ...fuelEntry,
                              'vehicle_id': vehicleInfo['vehicle_id'],
                              'vehicle_plate': vehicleInfo['vehicle_plate'],
                            },
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Sipanje goriva zabilježeno!"),
                            ),
                          );
                        }

                        if (mounted) {
                          Navigator.of(context).pop();
                          await Future.delayed(Duration(milliseconds: 100));
                          if (mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => DriverOrderScanScreen(),
                              ),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(resp['message'] ?? 'Greška!')),
                        );
                      }
                    },
                  ),

                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).maybePop(plate);
                    widget.onDetected?.call(plate);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

  InputImage _toInputImage(CameraImage image, int rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(
      image.width.toDouble(),
      image.height.toDouble(),
    );

    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(rotation) ??
        InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
        InputImageFormat.yuv420;

    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  String? _extractPlateFrom(
    RecognizedText recognized,
    double imgW,
    double imgH,
  ) {
    final roi = Rect.fromCenter(
      center: Offset(imgW / 2, imgH / 2),
      width: imgW * _roiW,
      height: imgH * _roiH,
    );

    final sb = StringBuffer();

    for (final block in recognized.blocks) {
      final bb = block.boundingBox;
      if (bb != null) {
        final c = bb.center;
        if (roi.contains(c)) {
          sb.writeln(block.text);
        }
      } else {
        for (final line in block.lines) {
          final lb = line.boundingBox;
          if (lb != null && roi.contains(lb.center)) {
            sb.writeln(line.text);
          }
        }
      }
    }

    final inRoiText = sb.isEmpty ? recognized.text : sb.toString();
    return _normalizeAndMatch(inRoiText);
  }

  String? _extractPlateHeuristic(RecognizedText recognized) {
    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final t = line.text.trim();
        if (t.length >= 6 && t.length <= 10) lines.add(t);
      }
    }
    final joined = (lines.isNotEmpty ? lines.join(' ') : recognized.text);
    return _normalizeAndMatch(joined);
  }

  String? _normalizeAndMatch(String text) {
    var s = text.toUpperCase().replaceAll('—', '-');

    s = s
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'[^A-Z0-9\- ]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    s = s
        .replaceAllMapped(RegExp(r'\bO(?=\d)\b'), (m) => '0')
        .replaceAll('I', '1')
        .replaceAll('S', '5')
        .replaceAll('B', '8');

    for (final re in [_bih, _euLike, _numLet]) {
      final m = re.firstMatch(s);
      if (m != null) {
        final parts = List.generate(m.groupCount, (i) => m.group(i + 1) ?? '');
        return parts.join('-');
      }
    }
    return null;
  }

  Future<void> _toggleTorch() async {
    if (_controller == null) return;
    try {
      _torchOn = !_torchOn;
      await _controller!.setFlashMode(
        _torchOn ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) setState(() {});
    } catch (_) {
      _torchOn = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Blic nije podržan na ovom uređaju.')),
        );
      }
    }
  }

  Future<void> _safeSetFocusExposure(Offset point01) async {
    try {
      await _controller?.setFocusPoint(point01);
    } catch (_) {}
    try {
      await _controller?.setExposurePoint(point01);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller?.dispose();
    _recognizer.close();
    _throttle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final initialized = c?.value.isInitialized ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: !initialized
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final size = MediaQuery.of(context).size;
                final p = Offset(
                  d.localPosition.dx / size.width,
                  d.localPosition.dy / size.height,
                );
                _safeSetFocusExposure(p);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(c!),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;
                      final roiw = w * _roiW;
                      final roih = h * _roiH;
                      return Center(
                        child: Container(
                          width: roiw,
                          height: roih,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 40,
                    right: 20,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      onPressed: () => _onHit("A12-B-234"),
                      child: const Text("Testiraj tablicu"),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Text(
                          _stillsMode
                              ? 'Kadriraj tablicu i pritisni “Slikaj OCR”'
                              : 'Poravnaj tablicu u prozoru — prepoznaje se automatski',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _IconButton(
                              icon: _torchOn ? Icons.flash_on : Icons.flash_off,
                              label: 'Torch',
                              onTap: _toggleTorch,
                            ),
                            const SizedBox(width: 16),
                            _IconButton(
                              icon: _stillsMode ? Icons.videocam : Icons.camera,
                              label: _stillsMode ? 'Stream' : 'Stills',
                              onTap: () async {
                                _stillsMode = !_stillsMode;
                                if (_stillsMode) {
                                  try {
                                    await _controller?.stopImageStream();
                                  } catch (_) {}
                                } else {
                                  try {
                                    await _controller?.startImageStream(
                                      _onNewFrame,
                                    );
                                  } catch (_) {}
                                }
                                if (mounted) setState(() {});
                              },
                            ),
                            const SizedBox(width: 16),
                            if (_stillsMode)
                              _IconButton(
                                icon: Icons.camera_alt,
                                label: 'Slikaj OCR',
                                onTap: _captureAndRecognize,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
