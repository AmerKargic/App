import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'barcode_scanner_controller.dart'; // Your existing controller

class BarcodeScannerScreen extends StatefulWidget {
  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final BarcodeScannerController controller = Get.put(
    BarcodeScannerController(),
  );
  MobileScannerController cameraController = MobileScannerController();
  final TextEditingController textController = TextEditingController();

  bool _scanned = false;

  AnimationController? _lineAnimController;
  Animation<double>? _linePosition;

  StreamSubscription? _loadingSub, _productSub, _errorSub;

  @override
  void initState() {
    super.initState();
    // Initialize camera controller
    controller.debugPrintSession();
    _lineAnimController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _linePosition = Tween<double>(begin: 0.18, end: 0.82).animate(
      CurvedAnimation(parent: _lineAnimController!, curve: Curves.easeInOut),
    );

    // SAFE listeners with cancel
    _loadingSub = controller.isLoading.listen((isLoading) {
      if (isLoading && mounted) {
        setState(() {
          _scanned = true;
        });
      }
    });

    _productSub = controller.productInfo.listen((product) {
      if (product.isNotEmpty && mounted) {
        setState(() {
          _scanned = true;
        });
      }
    });

    _errorSub = controller.error.listen((err) {
      if (err.isNotEmpty && mounted) {
        setState(() {
          _scanned = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _lineAnimController?.dispose();
    cameraController.dispose();
    _loadingSub?.cancel();
    _productSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.first.rawValue;
    if (barcode != null && controller.isLoading.isFalse) {
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() => _scanned = true);
      cameraController.stop();
      await controller.fetchProduct(barcode);

      // Camera will stay paused until user taps "Scan Another"
    }
  }

  void _resetScanner() {
    _lineAnimController?.dispose();
    cameraController.dispose();
    _loadingSub?.cancel();
    _productSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
    // Reset level if needed
    if (!mounted) return;
    setState(() => _scanned = false);
    cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    final double safeTop = MediaQuery.of(context).padding.top + 24;

    return Scaffold(
      backgroundColor: Colors.white, // Always light!
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.96),
        elevation: 1,

        title: Text('Skeniraj barkod (${controller.level.value})'),
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.bug_report),
            tooltip: 'Test scan (for emulator)',
            onPressed: () {
              HapticFeedback.lightImpact();
              if (!mounted) return;
              setState(() => _scanned = true);
              cameraController.stop();
              controller.fetchProduct("1234567890123");
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Offstage(
            offstage: true,
            child: TextField(
              autofocus: true,
              controller: textController,
              onSubmitted: (code) {
                textController.clear();
                controller.fetchProduct(code);
              },
            ),
          ),
          // Camera preview (fullscreen)
          Offstage(
            offstage: _scanned,
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                ),
                ScannerOverlay(animation: _linePosition, safeTop: safeTop),
              ],
            ),
          ),

          // Top Glassy Bar for branding/alignment (empty for now)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassBar(height: safeTop),
          ),

          // Flashlight button (bottom right)
          if (!_scanned)
            Positioned(
              bottom: 40,
              right: 32,
              child: GlassIconButton(
                icon: Icons.flash_on,
                tooltip: "Flashlight",
                onTap: () {
                  cameraController.toggleTorch();
                },
              ),
            ),

          // Exit button (top left)
          if (!_scanned)
            Positioned(
              top: safeTop / 2,
              left: 16,
              child: GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: "Close scanner",
                onTap: () {
                  Get.back();
                },
              ),
            ),

          // Product info modal (Glass effect, light background)
          if (_scanned)
            ProductModal(
              controller: controller,
              onScanAnother: _resetScanner,
              memeImagePath: "assets/images/404.png",
            ),
        ],
      ),
    );
  }
}

// --- Glassy Top Bar (empty for now) ---
class GlassBar extends StatelessWidget {
  final double height;
  const GlassBar({this.height = 56});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(height: height, color: Colors.white.withOpacity(0.07)),
      ),
    );
  }
}

// --- Glassy Icon Button ---
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.black, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// --- Animated Scanner Overlay (Glass + animated line) ---
class ScannerOverlay extends StatelessWidget {
  final Animation<double>? animation;
  final double safeTop;
  const ScannerOverlay({this.animation, required this.safeTop});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final scanBoxHeight = height * 0.45;
          final scanBoxTop = safeTop + 32;
          return Stack(
            children: [
              // Center glass box
              Positioned(
                top: scanBoxTop,
                left: width * 0.09,
                child: ClipRRect(borderRadius: BorderRadius.circular(32)),
              ),
              // Animated scanner line
              if (animation != null)
                AnimatedBuilder(
                  animation: animation!,
                  builder: (_, __) {
                    final top =
                        scanBoxTop + animation!.value * scanBoxHeight - 6;
                    return Positioned(
                      left: width * 0.12,
                      right: width * 0.12,
                      top: top,
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          gradient: LinearGradient(
                            colors: [
                              Colors.purpleAccent.withOpacity(0.8),
                              Colors.deepPurple.withOpacity(0.7),
                              Colors.purpleAccent.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withOpacity(0.22),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

// --- Product Info Modal (Glass, no dark background) ---
class ProductModal extends StatelessWidget {
  final BarcodeScannerController controller;
  final VoidCallback onScanAnother;
  final String memeImagePath;
  const ProductModal({
    required this.controller,
    required this.onScanAnother,
    required this.memeImagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // If loading: show skeleton loader
      if (controller.isLoading.value) {
        return _ModalGlass(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitThreeBounce(
                  color: const Color.fromARGB(255, 20, 136, 49),
                  size: 38,
                ),
                SizedBox(height: 20),
                _Skeleton(width: 120, height: 18),
                SizedBox(height: 16),
                _Skeleton(width: 220, height: 18),
                SizedBox(height: 8),
                _Skeleton(width: 190, height: 16),
                SizedBox(height: 26),
                _Skeleton(width: 300, height: 90, borderRadius: 16),
              ],
            ),
          ),
        );
      }

      if (controller.error.isNotEmpty) {
        return _ModalGlass(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
                SizedBox(height: 20),
                Text(
                  controller.error.value,
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 28),
                _ScanAgainBtn(onScanAnother),
              ],
            ),
          ),
        );
      }

      if (controller.productInfo.isEmpty) {
        return _ModalGlass(
          child: Center(
            child: Text(
              'Skenirajte barkod proizvoda.',
              style: TextStyle(fontSize: 18),
            ),
          ),
        );
      }

      // Got product: show all info in nice glass popup
      final product = controller.productInfo;
      final wishstocks = List<Map>.from(product['wishstock'] ?? []);

      return _ModalGlass(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 32, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product image or meme fallback
              _ProductImage(url: product['image'], fallback: memeImagePath),
              SizedBox(height: 22),
              Text(
                product['name'] ?? '',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'EAN: ${product['EAN'] ?? ""}',
                style: TextStyle(color: Colors.black87),
              ),
              SizedBox(height: 6),
              Text(
                'Cijena ${product['MPC'] ?? ""}',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),

              Text(
                'Cijena ${product['MPC_jednokratno'] ?? ""}',
                style: TextStyle(fontSize: 16, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Stanja po poslovnicama:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6),
              ...wishstocks.asMap().entries.map((entry) {
                final i = entry.key;
                final w = entry.value;
                final isMine = controller.isOwnStore(w);

                return Card(
                  shape: isMine
                      ? RoundedRectangleBorder(
                          side: BorderSide(
                            color: const Color.fromARGB(255, 39, 177, 69),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  color: isMine ? Colors.deepPurple.shade50 : null,
                  child: ListTile(
                    title: Text(
                      w['name'] ?? '',
                      style: TextStyle(
                        fontWeight: isMine
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: Colors.black,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stanje: ${w['stock']}',
                          style: TextStyle(color: Colors.black),
                        ),
                        Text(
                          'Željeno stanje: ${w['stock_wish']}',
                          style: TextStyle(color: Colors.black),
                        ),
                      ],
                    ),

                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: controller.level.value == 'admin'
                              ? (w['stock_wish_locked'] == "1"
                                    ? 'Otključaj'
                                    : 'Zaključaj')
                              : 'Samo admin može zaključavati',

                          child: IconButton(
                            icon: Icon(
                              (w['stock_wish_locked'].toString() == "1")
                                  ? Icons.lock
                                  : Icons.lock_open,

                              color: (w['stock_wish_locked'].toString() == "1")
                                  ? Colors.red
                                  : Colors.green,
                            ),

                            onPressed: controller.level.value == 'admin'
                                ? () => controller.toggleLock(i)
                                : null,
                          ),
                        ),
                        if (controller.canEditWishstock(w))
                          IconButton(
                            icon: Icon(Icons.edit, color: Colors.green),
                            tooltip: 'Uredi željeno stanje',
                            onPressed: () =>
                                _showEditDialog(context, i, w, controller),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              if (controller.changedIndexes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.save),
                    label: Text("Sačuvaj izmjene"),
                    onPressed: controller.saveWishstockChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      minimumSize: Size(170, 44),
                      textStyle: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
              SizedBox(height: 28),
              _ScanAgainBtn(onScanAnother),
            ],
          ),
        ),
      );
    });
  }

  void _showEditDialog(
    BuildContext context,
    int index,
    Map item,
    BarcodeScannerController controller,
  ) {
    final controllerText = TextEditingController(
      text: item['stock_wish'].toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Uredi željeno stanje'),
        content: TextField(
          controller: controllerText,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'Unesi novu vrijednost'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Otkaži'),
          ),
          TextButton(
            onPressed: () {
              final newVal =
                  double.tryParse(controllerText.text) ?? item['stock_wish'];
              controller.updateWishstock(index, newVal);
              Navigator.pop(context);
            },
            child: Text('Spremi'),
          ),
        ],
      ),
    );
  }
}

// --- Glassy Modal Wrapper ---
class _ModalGlass extends StatelessWidget {
  final Widget child;
  const _ModalGlass({required this.child});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 380,
              minWidth: 260,
              minHeight: 200,
              maxHeight: 630,
            ),
            padding: EdgeInsets.all(0),
            color: Colors.white.withOpacity(0.92), // Light glass, not dark
            child: child,
          ),
        ),
      ),
    );
  }
}

// --- Skeleton Loader Widget ---
class _Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _Skeleton({
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withOpacity(0.31),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

// --- Scan Again Button ---
class _ScanAgainBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _ScanAgainBtn(this.onTap);
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(Icons.camera_alt_outlined),
      label: Text("Skeniraj novi"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 3,
        minimumSize: Size(160, 40),
      ),
    );
  }
}

// --- Product Image with Meme Fallback ---
class _ProductImage extends StatelessWidget {
  final String? url;
  final String fallback;
  const _ProductImage({this.url, required this.fallback});
  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _MemeFallback(fallback: fallback);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Image.network(
        url!,
        height: 128,
        width: 128,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => _MemeFallback(fallback: fallback),
        loadingBuilder: (ctx, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _Skeleton(width: 128, height: 128, borderRadius: 18);
        },
      ),
    );
  }
}

class _MemeFallback extends StatelessWidget {
  final String fallback;
  const _MemeFallback({required this.fallback});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(fallback, width: 110, height: 110, fit: BoxFit.cover),
        SizedBox(height: 8),
        Text(
          "We had one job.\nFailed to load product image 😅",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
