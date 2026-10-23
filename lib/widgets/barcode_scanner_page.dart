import 'package:flutter/material.dart' hide Text;
import '../l10n/auto_translate.dart';
import '../l10n/gtext.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/gp_colors.dart';

/// Opens the camera and returns the first barcode / QR value it reads, or null if the user goes back.
/// Needs camera permission: Android adds it automatically; iOS needs NSCameraUsageDescription in Info.plist.
Future<String?> scanBarcode(BuildContext context) {
  return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ScannerPage()));
}

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue;
      if (v != null && v.trim().isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(v.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Scan barcode"),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded), tooltip: trs("Torch"), onPressed: () => _controller.toggleTorch()),
          IconButton(icon: const Icon(Icons.cameraswitch_rounded), tooltip: trs("Switch camera"), onPressed: () => _controller.switchCamera()),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Camera is not available. Allow camera access for this app in your phone settings, then try again.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: GPColors.accent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: Text("Point the camera at the barcode", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
