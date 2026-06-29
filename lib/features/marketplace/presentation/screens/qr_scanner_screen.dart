import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../domain/failures/marketplace_failure.dart';
import '../providers/marketplace_providers.dart';

/// Screen performing QR camera scanning to verify handshake.
class QrScannerScreen extends ConsumerStatefulWidget {
  final String listingId;

  const QrScannerScreen({
    super.key,
    required this.listingId,
  });

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetected(String payload) async {
    if (_hasScanned) return;
    setState(() {
      _hasScanned = true;
    });

    // Pause camera scanning
    _controller.stop();

    final actions = ref.read(marketplaceActionsProvider);
    final result = await actions.verifyHandshake(
      listingId: widget.listingId,
      payload: payload,
    );

    if (mounted) {
      switch (result) {
        case MarketSuccess<void>():
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Handshake verified successfully! Purchase is pending.'),
              backgroundColor: Colors.green,
            ),
          );
          // Invalidate listing details to reload status
          ref.invalidate(listingDetailsProvider(widget.listingId));
          // Go back to the listing detail screen
          Navigator.of(context).pop();
          break;
        case MarketFailed<void>(:final failure):
          _showFailureDialog(failure.message);
          break;
      }
    }
  }

  void _showFailureDialog(String message) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Verification Failed', style: TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Resume scanner
              setState(() {
                _hasScanned = false;
              });
              _controller.start();
            },
            child: const Text('Retry', style: TextStyle(color: Color(0xFF00B0FF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Scan QR Code',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF880E4F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: _controller,
            onDetect: (BarcodeCapture capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleQrDetected(rawValue);
                  break;
                }
              }
            },
          ),

          // QR Code scanner overlay/frame decoration
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00B0FF), width: 3),
                borderRadius: BorderRadius.circular(24),
                color: Colors.transparent,
              ),
            ),
          ),

          // User guidance text
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Align the seller\'s QR code within the frame to verify the handshake.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ),

          if (_hasScanned)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B0FF)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
